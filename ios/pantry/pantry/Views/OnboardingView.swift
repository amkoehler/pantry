import SwiftUI
import SwiftData

/// Onboarding flow for first-launch users.
/// Creates initial preferences and generates the first weekly draft.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    var onComplete: (() -> Void)?

    @State private var step: OnboardingStep = .welcome
    @State private var glutenFree = false
    @State private var dairyFree = false
    @State private var nutFree = false
    @State private var isGenerating = false
    @State private var error: String?

    enum OnboardingStep {
        case welcome
        case dietary
        case generating
    }

    var body: some View {
        ZStack {
            PantryTheme.Colors.background
                .ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeStepView(onContinue: { step = .dietary })
            case .dietary:
                DietaryStepView(
                    glutenFree: $glutenFree,
                    dairyFree: $dairyFree,
                    nutFree: $nutFree,
                    onContinue: startGeneration,
                    onSkip: startGeneration
                )
            case .generating:
                GeneratingStepView(error: error, onRetry: startGeneration)
            }
        }
        .animation(.easeInOut, value: step)
    }

    private func startGeneration() {
        step = .generating
        error = nil

        Task {
            await generateFirstDraft()
        }
    }

    @MainActor
    private func generateFirstDraft() async {
        do {
            // 1. Fetch meals from API (network call)
            print("[Onboarding] Fetching meals from API...")
            let mealsResponse = try await APIService.shared.fetchMeals(
                glutenFree: glutenFree,
                dairyFree: dairyFree,
                nutFree: nutFree
            )
            print("[Onboarding] Fetched \(mealsResponse.meals.count) meals")

            // 2. Insert meals into SwiftData (main actor)
            for apiMeal in mealsResponse.meals {
                let meal = apiMeal.toMeal()
                modelContext.insert(meal)
            }

            // 3. Create user preferences
            let preferences = UserPreferences(
                glutenFree: glutenFree,
                dairyFree: dairyFree,
                nutFree: nutFree,
                defaultDinnerCount: 5,
                hasCompletedOnboarding: false
            )
            preferences.lastMealSyncDate = Date()
            modelContext.insert(preferences)

            // 4. Save meals before generating draft
            try modelContext.save()

            // 5. Generate draft from API
            print("[Onboarding] Generating draft...")
            let request = DraftRequest(
                dinnerCount: 5,
                days: nil,  // Generate full week (days 1-5)
                busyDays: [],
                constraints: nil,
                mealHistory: [],
                dietaryFilters: DietaryFilters(
                    glutenFree: glutenFree,
                    dairyFree: dairyFree,
                    nutFree: nutFree
                )
            )

            let draftResponse = try await APIService.shared.generateDraft(request: request)
            print("[Onboarding] Draft generated with \(draftResponse.meals.count) meals")

            // 6. Create weekly plan
            let weekStart = currentWeekStart()
            let plan = WeeklyPlan(
                weekStartDate: weekStart,
                weekShape: .normal,
                dinnerCount: 5
            )
            modelContext.insert(plan)

            // 7. Create planned meals
            for draftMeal in draftResponse.meals {
                let meal = findMealByServerId(draftMeal.mealId) ?? findMealByTitle(draftMeal.mealTitle)
                let plannedMeal = PlannedMeal(dayOfWeek: draftMeal.dayOfWeek, meal: meal)
                plannedMeal.weeklyPlan = plan
                modelContext.insert(plannedMeal)
            }

            // 8. Mark onboarding complete and save
            preferences.hasCompletedOnboarding = true
            try modelContext.save()
            print("[Onboarding] Complete!")

            // 9. Notify parent to switch to main app
            onComplete?()

        } catch let apiError as APIError {
            print("[Onboarding] API Error: \(apiError.errorDescription ?? "unknown")")
            error = apiError.userMessage
        } catch {
            print("[Onboarding] Error: \(error)")
            self.error = "Unable to generate your first plan. Check your connection and try again."
        }
    }

    private func currentWeekStart() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get current weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
        let weekday = calendar.component(.weekday, from: today)

        // Calculate days to subtract to get to Monday
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)

        return calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
    }

    private func findMealByServerId(_ serverId: Int?) -> Meal? {
        guard let serverId = serverId else { return nil }
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func findMealByTitle(_ title: String) -> Meal? {
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.title == title }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Welcome Step

private struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 64))
                    .foregroundStyle(PantryTheme.Colors.accent)

                Text("Pantry")
                    .font(PantryTheme.Typography.display)
                    .foregroundStyle(PantryTheme.Colors.primaryText)
            }

            Text("We help you plan weeknight dinners without starting from scratch every time.")
                .font(PantryTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(PantryTheme.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Dietary Step

private struct DietaryStepView: View {
    @Binding var glutenFree: Bool
    @Binding var dairyFree: Bool
    @Binding var nutFree: Bool
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Any dietary restrictions?")
                    .font(PantryTheme.Typography.title)
                    .foregroundStyle(PantryTheme.Colors.primaryText)

                Text("We'll filter out meals that don't work for you.")
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.secondaryText)
            }

            VStack(spacing: 12) {
                DietaryToggle(
                    title: "Gluten-Free",
                    isOn: $glutenFree
                )
                DietaryToggle(
                    title: "Dairy-Free",
                    isOn: $dairyFree
                )
                DietaryToggle(
                    title: "Nut-Free",
                    isOn: $nutFree
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(PantryTheme.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(PantryTheme.Typography.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

private struct DietaryToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(PantryTheme.Typography.body)
            .foregroundStyle(PantryTheme.Colors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PantryTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.badge))
    }
}

// MARK: - Generating Step

private struct GeneratingStepView: View {
    let error: String?
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(PantryTheme.Colors.tertiaryText)

                    Text(error)
                        .font(PantryTheme.Typography.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PantryTheme.Colors.secondaryText)
                        .padding(.horizontal, 32)

                    Button(action: onRetry) {
                        Text("Try Again")
                            .font(PantryTheme.Typography.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Creating your first plan...")
                        .font(PantryTheme.Typography.body)
                        .foregroundStyle(PantryTheme.Colors.secondaryText)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
}
