import Foundation
import SwiftData
import Observation
import UIKit

// MARK: - Date Provider Protocol

/// Protocol for injecting date/time for testability
protocol DateProviding {
    func now() -> Date
}

/// Default implementation using system time
struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}

/// ViewModel for the weekly plan view, managing state and data loading.
@Observable
@MainActor
class WeeklyPlanViewModel {

    // MARK: - View State

    enum ViewState: Equatable {
        case loading
        case empty
        case populated
        case error(String)
    }

    enum WeekSelection {
        case current
        case next
    }

    // MARK: - Published State

    var viewState: ViewState = .loading
    var currentWeekPlan: WeeklyPlan?
    var nextWeekPlan: WeeklyPlan?
    var selectedWeek: WeekSelection = .current

    // Swap sheet state
    var selectedPlannedMealForSwap: PlannedMeal?
    var isSwapSheetPresented: Bool = false

    // Draft generation state
    var isGeneratingDraft: Bool = false
    var generationError: String?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let dateProvider: DateProviding

    // MARK: - Computed Properties

    /// The currently displayed plan based on week selection
    var displayedPlan: WeeklyPlan? {
        selectedWeek == .current ? currentWeekPlan : nextWeekPlan
    }

    /// Title for the navigation bar - shows date range like "Jan 6 – 10"
    var weekDisplayTitle: String {
        let weekStart = selectedWeek == .current ? currentWeekStart() : nextWeekStart()
        return formatWeekRange(from: weekStart)
    }

    /// Format a week range like "Jan 6 – 10" or "Jan 27 – Feb 2" if spanning months
    private func formatWeekRange(from monday: Date) -> String {
        let calendar = Calendar.current
        guard let friday = calendar.date(byAdding: .day, value: 4, to: monday) else {
            return ""
        }

        let mondayMonth = calendar.component(.month, from: monday)
        let fridayMonth = calendar.component(.month, from: friday)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        if mondayMonth == fridayMonth {
            // Same month: "Jan 6 – 10"
            return "\(monthFormatter.string(from: monday)) \(dayFormatter.string(from: monday)) – \(dayFormatter.string(from: friday))"
        } else {
            // Different months: "Jan 27 – Feb 2"
            return "\(monthFormatter.string(from: monday)) \(dayFormatter.string(from: monday)) – \(monthFormatter.string(from: friday)) \(dayFormatter.string(from: friday))"
        }
    }

    /// Filtered meals for current week (shows all weekdays M-F, past days shown as non-interactive)
    var currentWeekFilteredMeals: [PlannedMeal] {
        guard let plan = currentWeekPlan,
              let meals = plan.plannedMeals else { return [] }

        // Show all weekdays M-F, no longer filtering past days
        return meals
            .filter { $0.dayOfWeek <= 5 }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    /// Check if a day is in the past (before today)
    func isPastDay(_ dayOfWeek: Int) -> Bool {
        return dayOfWeek < currentDayOfWeek()
    }

    /// All meals for next week (no mid-week filter)
    var nextWeekFilteredMeals: [PlannedMeal] {
        guard let plan = nextWeekPlan,
              let meals = plan.plannedMeals else { return [] }

        return meals.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    /// Meals for the currently selected week
    var visiblePlannedMeals: [PlannedMeal] {
        selectedWeek == .current ? currentWeekFilteredMeals : nextWeekFilteredMeals
    }

    // MARK: - Initialization

    init(modelContext: ModelContext, dateProvider: DateProviding = SystemDateProvider()) {
        self.modelContext = modelContext
        self.dateProvider = dateProvider

        // Default to next week on weekends (Sat=6, Sun=7)
        // Note: Can't call currentDayOfWeek() before self is fully initialized,
        // so we inline the calculation here
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: dateProvider.now())
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1  // Convert to Mon=1...Sun=7

        if dayOfWeek >= 6 {
            self.selectedWeek = .next
        }
    }

    // MARK: - Public Methods

    /// Load plans for current and next week from SwiftData
    func loadPlans() async {
        viewState = .loading

        do {
            let currentStart = currentWeekStart()
            let nextStart = nextWeekStart()

            print("[ViewModel] Loading plans...")
            print("[ViewModel] Looking for currentWeekStart: \(currentStart)")

            // Debug: fetch ALL plans to see what exists
            let allPlans = try modelContext.fetch(FetchDescriptor<WeeklyPlan>())
            print("[ViewModel] Total plans in DB: \(allPlans.count)")
            for plan in allPlans {
                print("[ViewModel]   - Plan weekStartDate: \(plan.weekStartDate), meals: \(plan.plannedMeals?.count ?? 0)")
            }

            // Fetch current week plan
            let currentPredicate = #Predicate<WeeklyPlan> { plan in
                plan.weekStartDate == currentStart
            }
            let currentDescriptor = FetchDescriptor<WeeklyPlan>(predicate: currentPredicate)
            currentWeekPlan = try modelContext.fetch(currentDescriptor).first

            // Fetch next week plan
            let nextPredicate = #Predicate<WeeklyPlan> { plan in
                plan.weekStartDate == nextStart
            }
            let nextDescriptor = FetchDescriptor<WeeklyPlan>(predicate: nextPredicate)
            nextWeekPlan = try modelContext.fetch(nextDescriptor).first

            print("[ViewModel] Found currentWeekPlan: \(currentWeekPlan != nil)")
            print("[ViewModel] currentWeekPlan meals: \(currentWeekPlan?.plannedMeals?.count ?? 0)")
            print("[ViewModel] visiblePlannedMeals: \(visiblePlannedMeals.count)")

            // Update state based on what we found
            if displayedPlan != nil && !(visiblePlannedMeals.isEmpty) {
                viewState = .populated
            } else {
                viewState = .empty
            }
        } catch {
            viewState = .error("Unable to load your plan")
        }
    }

    /// Switch between current and next week
    func switchToWeek(_ week: WeekSelection) {
        selectedWeek = week

        // Update view state based on new selection
        if displayedPlan != nil && !visiblePlannedMeals.isEmpty {
            viewState = .populated
        } else {
            viewState = .empty
        }
    }

    /// Open swap sheet for a planned meal
    func selectMealForSwap(_ plannedMeal: PlannedMeal) {
        selectedPlannedMealForSwap = plannedMeal
        isSwapSheetPresented = true
    }

    // MARK: - Meal Reordering

    /// Swap meal assignments between two planned meal slots (drag and drop)
    func swapMeals(source: PlannedMeal, target: PlannedMeal) {
        // Guard: same weekly plan (no cross-week swaps)
        guard source.weeklyPlan?.id == target.weeklyPlan?.id else { return }
        // Guard: not the same slot
        guard source.id != target.id else { return }

        // Swap meal references and skip status
        let sourceMeal = source.meal
        let sourceIsSkipped = source.isSkipped

        source.meal = target.meal
        source.isSkipped = target.isSkipped

        target.meal = sourceMeal
        target.isSkipped = sourceIsSkipped

        // Haptic feedback on success
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Save to SwiftData
        try? modelContext.save()
    }

    /// Handle the result of a swap operation
    func handleSwapResult(newMeal: Meal?, wasSkipped: Bool) {
        guard let plannedMeal = selectedPlannedMealForSwap else { return }

        // Record outcome for the original meal
        if let originalMeal = plannedMeal.meal {
            let outcomeType: Outcome = wasSkipped ? .skipped : .swapped
            let outcome = MealOutcome(outcome: outcomeType, recordedAt: Date())
            outcome.plannedMeal = plannedMeal
            modelContext.insert(outcome)
            plannedMeal.outcome = outcome
        }

        // Update the planned meal
        if wasSkipped {
            plannedMeal.isSkipped = true
            plannedMeal.meal = nil
        } else if let newMeal = newMeal {
            plannedMeal.meal = newMeal
            plannedMeal.isSkipped = false
        }

        // Save context
        try? modelContext.save()

        // Reset swap sheet state
        selectedPlannedMealForSwap = nil
        isSwapSheetPresented = false
    }

    /// Dismiss the swap sheet without making changes
    func dismissSwapSheet() {
        selectedPlannedMealForSwap = nil
        isSwapSheetPresented = false
    }

    // MARK: - Draft Generation

    /// Generate a new draft for the specified week (defaults to selected week)
    func generateDraft(forWeek weekStart: Date? = nil) async {
        isGeneratingDraft = true
        generationError = nil

        do {
            // 1. Get or create UserPreferences
            let preferences = fetchUserPreferences() ?? createDefaultPreferences()

            // 2. Sync meals from API (fetch then insert on main actor)
            try await syncMealsFromAPI(preferences: preferences)

            // 3. Build draft request
            let history = fetchPlannedMealsForHistory()
            let request = APIService.buildDraftRequest(
                dinnerCount: preferences.defaultDinnerCount,
                weekShape: .normal,
                busyDays: [],
                constraints: nil,
                mealHistory: history,
                preferences: preferences
            )

            // 4. Call API
            let response = try await APIService.shared.generateDraft(request: request)

            // 5. Create WeeklyPlan - use selected week if no explicit week provided
            let targetWeekStart = weekStart ?? (selectedWeek == .next ? nextWeekStart() : currentWeekStart())

            // Delete existing plan for this week if any
            deleteExistingPlan(for: targetWeekStart)

            let plan = WeeklyPlan(
                weekStartDate: targetWeekStart,
                weekShape: .normal,
                dinnerCount: preferences.defaultDinnerCount
            )
            modelContext.insert(plan)

            // 6. Create PlannedMeal for each day in response
            for draftMeal in response.meals {
                let meal = findMealByServerId(draftMeal.mealId) ?? findMealByTitle(draftMeal.mealTitle)
                let plannedMeal = PlannedMeal(dayOfWeek: draftMeal.dayOfWeek, meal: meal)
                plannedMeal.weeklyPlan = plan
                modelContext.insert(plannedMeal)
            }

            // 7. Save and reload
            try modelContext.save()
            await loadPlans()

            // 8. Haptic feedback: tap once for each day in the plan
            await playDraftGeneratedHaptics(dayCount: response.meals.count)

        } catch let error as APIError {
            generationError = error.userMessage
            viewState = .error(error.userMessage)
        } catch {
            generationError = "Unable to generate plan. Check your connection."
            viewState = .error("Unable to generate plan. Check your connection.")
        }

        isGeneratingDraft = false
    }

    /// Regenerate draft for an existing plan (preserves past days, only regenerates today onwards)
    func regenerateDraft(for plan: WeeklyPlan) async {
        isGeneratingDraft = true
        generationError = nil

        do {
            // Get current day of week
            let today = currentDayOfWeek()

            // Weekend: no regeneration needed (next week plan should be shown instead)
            guard today <= 5 else {
                isGeneratingDraft = false
                return
            }

            // Get preferences
            let preferences = fetchUserPreferences() ?? createDefaultPreferences()

            // Sync meals from API
            try await syncMealsFromAPI(preferences: preferences)

            // Build array of days to regenerate (today through Friday)
            let daysToGenerate = Array(today...5)

            // Build request with plan's settings, specifying which days to generate
            let history = fetchPlannedMealsForHistory()
            let request = APIService.buildDraftRequest(
                dinnerCount: plan.dinnerCount,
                days: daysToGenerate,
                weekShape: plan.weekShape,
                busyDays: [],
                constraints: plan.constraints,
                mealHistory: history,
                preferences: preferences
            )

            // Generate new draft (only for specified days)
            let response = try await APIService.shared.generateDraft(request: request)

            // Delete only future planned meals (today onwards), preserve past days
            if let existingMeals = plan.plannedMeals {
                for meal in existingMeals where meal.dayOfWeek >= today {
                    modelContext.delete(meal)
                }
            }

            // Create new planned meals for the regenerated days
            for draftMeal in response.meals {
                let meal = findMealByServerId(draftMeal.mealId) ?? findMealByTitle(draftMeal.mealTitle)
                let plannedMeal = PlannedMeal(dayOfWeek: draftMeal.dayOfWeek, meal: meal)
                plannedMeal.weeklyPlan = plan
                modelContext.insert(plannedMeal)
            }

            // Save and reload
            try modelContext.save()
            await loadPlans()

            // Haptic feedback: tap once for each day in the plan
            await playDraftGeneratedHaptics(dayCount: response.meals.count)

        } catch let error as APIError {
            generationError = error.userMessage
        } catch {
            generationError = "Unable to regenerate plan. Check your connection."
        }

        isGeneratingDraft = false
    }

    /// Rapid-fire haptic taps, one for each day in the generated plan
    private func playDraftGeneratedHaptics(dayCount: Int) async {
        guard dayCount > 0 else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()

        for i in 0..<dayCount {
            generator.impactOccurred()
            if i < dayCount - 1 {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - Draft Generation Helpers

    /// Sync meals from API without crossing actor boundaries
    private func syncMealsFromAPI(preferences: UserPreferences) async throws {
        // Fetch from API (runs on APIService actor)
        let response = try await APIService.shared.fetchMeals(
            glutenFree: preferences.glutenFree,
            dairyFree: preferences.dairyFree,
            nutFree: preferences.nutFree
        )

        // Build lookup of existing meals by serverId
        let existingMeals = try modelContext.fetch(
            FetchDescriptor<Meal>(predicate: #Predicate { $0.serverId != nil })
        )
        var existingByServerId: [Int: Meal] = [:]
        for meal in existingMeals {
            if let serverId = meal.serverId {
                existingByServerId[serverId] = meal
            }
        }

        // Upsert meals (runs on main actor)
        for apiMeal in response.meals {
            if let existingMeal = existingByServerId[apiMeal.id] {
                // Update existing
                existingMeal.title = apiMeal.title
                existingMeal.prepRisk = PrepRisk(fromComplexity: apiMeal.complexity)
                existingMeal.containsGluten = apiMeal.containsGluten
                existingMeal.containsDairy = apiMeal.containsDairy
                existingMeal.containsNuts = apiMeal.containsNuts
                existingMeal.protein = apiMeal.protein
                existingMeal.cuisine = apiMeal.cuisine
                existingMeal.tags = apiMeal.tags
            } else {
                // Insert new
                let newMeal = apiMeal.toMeal()
                modelContext.insert(newMeal)
            }
        }

        preferences.lastMealSyncDate = Date()
        try modelContext.save()
    }

    private func createDefaultPreferences() -> UserPreferences {
        let prefs = UserPreferences()
        modelContext.insert(prefs)
        try? modelContext.save()
        return prefs
    }

    private func fetchPlannedMealsForHistory() -> [PlannedMeal] {
        let now = dateProvider.now()
        let eightWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
        let descriptor = FetchDescriptor<PlannedMeal>(
            predicate: #Predicate { $0.createdAt >= eightWeeksAgo }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteExistingPlan(for weekStart: Date) {
        let predicate = #Predicate<WeeklyPlan> { plan in
            plan.weekStartDate == weekStart
        }
        let descriptor = FetchDescriptor<WeeklyPlan>(predicate: predicate)

        if let existingPlans = try? modelContext.fetch(descriptor) {
            for plan in existingPlans {
                modelContext.delete(plan)
            }
        }
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

    // MARK: - Week Calculation Helpers

    /// Get Monday 00:00 of the current week
    func currentWeekStart() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: dateProvider.now())

        // Get current weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
        let weekday = calendar.component(.weekday, from: today)

        // Calculate days to subtract to get to Monday
        // Monday=2, so: Sun(1)->-6, Mon(2)->0, Tue(3)->-1, Wed(4)->-2, etc.
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)

        return calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
    }

    /// Get Monday 00:00 of next week
    func nextWeekStart() -> Date {
        let calendar = Calendar.current
        let current = currentWeekStart()
        return calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
    }

    /// Get current day of week (1=Monday, 7=Sunday)
    func currentDayOfWeek() -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: dateProvider.now())

        // Convert from Sunday=1...Saturday=7 to Monday=1...Sunday=7
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Get day name for a day of week number
    static func dayName(for dayOfWeek: Int) -> String {
        let names = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "" }
        return names[dayOfWeek]
    }

    // MARK: - Meal Fetching

    /// Fetch all available meals from SwiftData
    func fetchAvailableMeals() -> [Meal] {
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { !$0.isHidden },
            sortBy: [SortDescriptor(\.title)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Build swap context for Foundation Models
    func buildSwapContext(for plannedMeal: PlannedMeal) -> SwapContext? {
        guard let weeklyPlan = plannedMeal.weeklyPlan else { return nil }

        // Get other meal titles this week
        let otherMealTitles = (weeklyPlan.plannedMeals ?? [])
            .filter { $0.id != plannedMeal.id && !$0.isSkipped }
            .compactMap { $0.meal?.title }

        // Determine if this is a busy day based on week shape
        let isBusyDay: Bool
        switch weeklyPlan.weekShape {
        case .normal:
            isBusyDay = false
        case .busy:
            isBusyDay = [2, 4].contains(plannedMeal.dayOfWeek) // Tue, Thu
        case .chaotic:
            isBusyDay = true
        }

        // Get recent history (last 8 weeks)
        let recentHistory = fetchRecentMealHistory()

        // Get user preferences for dietary filters
        let preferences = fetchUserPreferences()

        return SwapContext(
            dayOfWeek: plannedMeal.dayOfWeek,
            isBusyDay: isBusyDay,
            otherMealTitles: otherMealTitles,
            recentHistory: recentHistory,
            weekShapeRaw: weeklyPlan.weekShape.rawValue,
            glutenFree: preferences?.glutenFree ?? false,
            dairyFree: preferences?.dairyFree ?? false,
            nutFree: preferences?.nutFree ?? false
        )
    }

    // MARK: - Private Helpers

    private func fetchRecentMealHistory() -> [SwapContext.MealHistoryContext] {
        let now = dateProvider.now()
        let eightWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: now) ?? now

        let descriptor = FetchDescriptor<MealOutcome>(
            predicate: #Predicate { $0.recordedAt >= eightWeeksAgo },
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )

        do {
            let outcomes = try modelContext.fetch(descriptor)
            return outcomes.compactMap { outcome -> SwapContext.MealHistoryContext? in
                guard let plannedMeal = outcome.plannedMeal,
                      let meal = plannedMeal.meal,
                      let weeklyPlan = plannedMeal.weeklyPlan else {
                    return nil
                }

                let weeksAgo = Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: weeklyPlan.weekStartDate,
                    to: now
                ).weekOfYear ?? 0

                return SwapContext.MealHistoryContext(
                    mealTitle: meal.title,
                    outcome: outcome.outcome.rawValue,
                    weeksAgo: weeksAgo
                )
            }
        } catch {
            return []
        }
    }

    private func fetchUserPreferences() -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>()
        return try? modelContext.fetch(descriptor).first
    }
}
