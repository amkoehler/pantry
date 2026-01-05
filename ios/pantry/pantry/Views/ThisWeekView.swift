import SwiftUI
import SwiftData

struct ThisWeekView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WeeklyPlanViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    WeekContentView(viewModel: viewModel)
                } else {
                    LoadingStateView()
                }
            }
            .navigationTitle(viewModel?.weekDisplayTitle ?? "This Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if let viewModel = viewModel {
                        Button(action: {
                            Task {
                                await viewModel.generateDraft()
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                        .disabled(viewModel.isGeneratingDraft)
                    }
                }
            }
        }
        .task {
            let vm = WeeklyPlanViewModel(modelContext: modelContext)
            viewModel = vm
            await vm.loadPlans()
        }
    }
}

// MARK: - Week Content View

/// Switches between different view states based on ViewModel state
private struct WeekContentView: View {
    @Bindable var viewModel: WeeklyPlanViewModel

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                LoadingStateView()
            case .empty:
                EmptyStateView(
                    isGenerating: viewModel.isGeneratingDraft,
                    onCreateDraft: {
                        Task {
                            await viewModel.generateDraft()
                        }
                    }
                )
            case .populated:
                WeekPlanScrollView(viewModel: viewModel)
            case .error(let message):
                ErrorStateView(message: message) {
                    Task {
                        await viewModel.loadPlans()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isSwapSheetPresented) {
            if let plannedMeal = viewModel.selectedPlannedMealForSwap {
                SwapSheetView(
                    plannedMeal: plannedMeal,
                    availableMeals: viewModel.fetchAvailableMeals(),
                    swapContext: viewModel.buildSwapContext(for: plannedMeal),
                    onSwap: { newMeal in
                        viewModel.handleSwapResult(newMeal: newMeal, wasSkipped: false)
                    },
                    onSkip: {
                        viewModel.handleSwapResult(newMeal: nil, wasSkipped: true)
                    },
                    onDismiss: {
                        viewModel.dismissSwapSheet()
                    }
                )
            }
        }
    }
}

// MARK: - Week Plan Scroll View

/// Horizontal paging between current and next week
private struct WeekPlanScrollView: View {
    @Bindable var viewModel: WeeklyPlanViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedWeek) {
            // Current Week Page
            WeekPageView(
                plannedMeals: viewModel.currentWeekFilteredMeals,
                weekPlan: viewModel.currentWeekPlan,
                onMealTap: viewModel.selectMealForSwap,
                onRegenerate: { plan in
                    Task {
                        await viewModel.regenerateDraft(for: plan)
                    }
                }
            )
            .tag(WeeklyPlanViewModel.WeekSelection.current)

            // Next Week Page
            WeekPageView(
                plannedMeals: viewModel.nextWeekFilteredMeals,
                weekPlan: viewModel.nextWeekPlan,
                onMealTap: viewModel.selectMealForSwap,
                onRegenerate: { plan in
                    Task {
                        await viewModel.regenerateDraft(for: plan)
                    }
                }
            )
            .tag(WeeklyPlanViewModel.WeekSelection.next)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .onChange(of: viewModel.selectedWeek) { _, newValue in
            viewModel.switchToWeek(newValue)
        }
    }
}

// MARK: - Week Page View

/// Single week's content with vertical scrolling meals and check-in section
private struct WeekPageView: View {
    let plannedMeals: [PlannedMeal]
    let weekPlan: WeeklyPlan?
    let onMealTap: (PlannedMeal) -> Void
    let onRegenerate: (WeeklyPlan) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Meal cards
                ForEach(plannedMeals) { plannedMeal in
                    DayCardView(plannedMeal: plannedMeal) {
                        onMealTap(plannedMeal)
                    }
                }

                // Check-in section (only show if we have a plan)
                if let plan = weekPlan {
                    Divider()
                        .padding(.vertical, 8)

                    CheckInView(weeklyPlan: plan) {
                        onRegenerate(plan)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(PantryTheme.Colors.background)
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Preparing your week...")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PantryTheme.Colors.background)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var isGenerating: Bool = false
    var onCreateDraft: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            if isGenerating {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Creating your plan...")
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.secondaryText)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 48))
                    .foregroundStyle(PantryTheme.Colors.tertiaryText)

                Text("No plan yet")
                    .font(PantryTheme.Typography.headline)
                    .foregroundStyle(PantryTheme.Colors.primaryText)

                Text("Your dinner plan will appear here once it's ready.")
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let onCreateDraft = onCreateDraft {
                    Button("Create your plan") {
                        onCreateDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PantryTheme.Colors.background)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(PantryTheme.Colors.tertiaryText)

            Text(message)
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PantryTheme.Colors.background)
    }
}

// MARK: - Preview

#Preview {
    ThisWeekView()
        .modelContainer(for: [
            Meal.self,
            WeeklyPlan.self,
            PlannedMeal.self,
            MealOutcome.self,
            UserPreferences.self
        ], inMemory: true)
}
