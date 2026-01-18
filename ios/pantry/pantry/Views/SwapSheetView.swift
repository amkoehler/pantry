import SwiftUI
import SwiftData

/// Modal sheet for swapping a planned meal with alternatives.
struct SwapSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plannedMeal: PlannedMeal
    let availableMeals: [Meal]
    let swapContext: SwapContext?
    let cachedSuggestions: [MealSuggestion]?
    let onSwap: (Meal) -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void
    let onSuggestionsLoaded: ([MealSuggestion]) -> Void

    @State private var suggestions: [MealSuggestion] = []
    @State private var isLoadingSuggestions = true
    @State private var customMealText = ""
    @State private var showHideConfirmation = false
    @State private var mealToHide: Meal?

    private var currentMeal: Meal? {
        plannedMeal.meal
    }

    private var dayName: String {
        WeeklyPlanViewModel.dayName(for: plannedMeal.dayOfWeek)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Current meal header
                    if let meal = currentMeal {
                        CurrentMealHeader(meal: meal, dayName: dayName)
                    } else {
                        Text("Add a meal for \(dayName)")
                            .font(PantryTheme.Typography.headline)
                            .foregroundStyle(PantryTheme.Colors.primaryText)
                    }

                    Divider()

                    // Suggestions section
                    SuggestionsSection(
                        suggestions: suggestions,
                        isLoading: isLoadingSuggestions,
                        onSelect: { meal in
                            onSwap(meal)
                            dismiss()
                        },
                        onLongPress: { meal in
                            mealToHide = meal
                            showHideConfirmation = true
                        }
                    )

                    Divider()

                    // Not cooking tonight
                    Button(action: {
                        onSkip()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "moon.zzz")
                            Text("Not cooking tonight")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    Divider()

                    // Custom meal entry
                    CustomMealSection(
                        text: $customMealText,
                        availableMeals: availableMeals,
                        onSubmit: handleCustomMealSubmit
                    )
                }
                .padding(20)
            }
            .background(PantryTheme.Colors.background)
            .navigationTitle(dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Hide meal", isPresented: $showHideConfirmation, presenting: mealToHide) { meal in
            Button("Hide", role: .destructive) {
                hideMeal(meal)
            }
            Button("Cancel", role: .cancel) {}
        } message: { meal in
            Text("Hide \"\(meal.title)\" from future plans?")
        }
        .task {
            await loadSuggestions()
        }
    }

    // MARK: - Actions

    private func loadSuggestions() async {
        // Use cached suggestions if available (instant load)
        if let cached = cachedSuggestions {
            suggestions = cached
            isLoadingSuggestions = false
            return
        }

        // Fall back to loading with spinner
        isLoadingSuggestions = true

        guard let currentMeal = currentMeal,
              let context = swapContext else {
            // No current meal or context - show random suggestions
            let fallbackSuggestions = availableMeals
                .filter { !$0.isHidden }
                .shuffled()
                .prefix(3)
                .map { MealSuggestion(meal: $0, reason: "Available option") }
            suggestions = fallbackSuggestions
            isLoadingSuggestions = false
            onSuggestionsLoaded(fallbackSuggestions)
            return
        }

        // Use Foundation Models for smart suggestions
        var loadedSuggestions: [MealSuggestion]
        if #available(iOS 26.0, *) {
            do {
                let service = FoundationModelsService.shared
                loadedSuggestions = try await service.suggestSwaps(
                    for: currentMeal,
                    context: context,
                    availableMeals: availableMeals
                )
            } catch {
                // Fallback to simple filtering
                loadedSuggestions = simpleSuggestions(excluding: currentMeal)
            }
        } else {
            loadedSuggestions = simpleSuggestions(excluding: currentMeal)
        }

        suggestions = loadedSuggestions
        isLoadingSuggestions = false

        // Cache for future opens
        onSuggestionsLoaded(loadedSuggestions)
    }

    private func simpleSuggestions(excluding currentMeal: Meal) -> [MealSuggestion] {
        availableMeals
            .filter { $0.id != currentMeal.id && !$0.isHidden }
            .shuffled()
            .prefix(3)
            .map { MealSuggestion(meal: $0, reason: "Available option") }
    }

    private func handleCustomMealSubmit() {
        let trimmed = customMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            // Try to match to existing meal
            if #available(iOS 26.0, *) {
                let service = FoundationModelsService.shared
                if let matchedMeal = try? await service.matchMeal(
                    userInput: trimmed,
                    availableMeals: availableMeals
                ) {
                    await MainActor.run {
                        onSwap(matchedMeal)
                        dismiss()
                    }
                    return
                }
            }

            // No match - create custom meal
            await MainActor.run {
                let customMeal = createCustomMeal(title: trimmed)
                onSwap(customMeal)
                dismiss()
            }
        }
    }

    private func createCustomMeal(title: String) -> Meal {
        let meal = Meal(
            title: title,
            prepRisk: .normal, // Default to normal, could use FM to infer
            isCustom: true
        )
        modelContext.insert(meal)
        return meal
    }

    private func hideMeal(_ meal: Meal) {
        meal.isHidden = true
        try? modelContext.save()

        // Remove from suggestions
        suggestions.removeAll { $0.meal.id == meal.id }

        // If we removed a suggestion, try to add another
        if suggestions.count < 3 {
            if let replacement = availableMeals.first(where: { candidate in
                !candidate.isHidden &&
                candidate.id != currentMeal?.id &&
                !suggestions.contains { $0.meal.id == candidate.id }
            }) {
                suggestions.append(MealSuggestion(meal: replacement, reason: "Available option"))
            }
        }
    }
}

// MARK: - Current Meal Header

private struct CurrentMealHeader: View {
    let meal: Meal
    let dayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayName)
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)

            Text(meal.title)
                .font(PantryTheme.Typography.title)
                .foregroundStyle(PantryTheme.Colors.primaryText)

            HStack(spacing: 6) {
                if meal.prepRisk == .fast {
                    PrepBadge(label: "Easy")
                }
                if meal.onePotOrPan == "one-pot" {
                    PrepBadge(label: "One-Pot")
                } else if meal.onePotOrPan == "one-pan" {
                    PrepBadge(label: "One-Pan")
                }
            }
        }
    }
}

// MARK: - Suggestions Section

private struct SuggestionsSection: View {
    let suggestions: [MealSuggestion]
    let isLoading: Bool
    let onSelect: (Meal) -> Void
    let onLongPress: (Meal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alternatives")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(suggestions) { suggestion in
                    AlternativeMealRow(
                        suggestion: suggestion,
                        onSelect: { onSelect(suggestion.meal) },
                        onLongPress: { onLongPress(suggestion.meal) }
                    )
                }
            }
        }
    }
}

// MARK: - Alternative Meal Row

private struct AlternativeMealRow: View {
    let suggestion: MealSuggestion
    let onSelect: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.meal.title)
                    .font(PantryTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(PantryTheme.Colors.primaryText)

                HStack(spacing: 6) {
                    if suggestion.meal.prepRisk == .fast {
                        PrepBadge(label: "Easy")
                    }
                    if suggestion.meal.onePotOrPan == "one-pot" {
                        PrepBadge(label: "One-Pot")
                    } else if suggestion.meal.onePotOrPan == "one-pan" {
                        PrepBadge(label: "One-Pan")
                    }
                }

                if !suggestion.reason.isEmpty && suggestion.reason != "Available option" {
                    Text(suggestion.reason)
                        .font(PantryTheme.Typography.caption)
                        .foregroundStyle(PantryTheme.Colors.secondaryText)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PantryTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.badge))
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Custom Meal Section

private struct CustomMealSection: View {
    @Binding var text: String
    let availableMeals: [Meal]
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or enter your own")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)

            TextField("Tacos, leftover pasta, etc.", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSubmit)
                .submitLabel(.done)
        }
    }
}

// MARK: - Preview

#Preview {
    let meal = Meal(title: "Chicken Stir Fry", prepRisk: .fast)
    let plannedMeal = PlannedMeal(dayOfWeek: 1, meal: meal)

    SwapSheetView(
        plannedMeal: plannedMeal,
        availableMeals: [
            Meal(title: "Tacos", prepRisk: .fast),
            Meal(title: "Pasta Carbonara", prepRisk: .normal),
            Meal(title: "Grilled Salmon", prepRisk: .normal)
        ],
        swapContext: nil,
        cachedSuggestions: nil,
        onSwap: { _ in },
        onSkip: {},
        onDismiss: {},
        onSuggestionsLoaded: { _ in }
    )
}
