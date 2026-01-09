import Foundation
import FoundationModels

// MARK: - Context Types

/// Context provided to Foundation Models for generating swap suggestions.
struct SwapContext: Sendable {
    /// Day of week being swapped (1=Monday, 7=Sunday)
    let dayOfWeek: Int

    /// Whether this day is marked as busy
    let isBusyDay: Bool

    /// Other meal titles already planned this week
    let otherMealTitles: [String]

    /// Recent meal history with outcomes (last 8 weeks)
    let recentHistory: [MealHistoryContext]

    /// The week shape (normal/busy/chaotic)
    let weekShapeRaw: String

    /// User's dietary restrictions
    let glutenFree: Bool
    let dairyFree: Bool
    let nutFree: Bool

    /// Helper struct for history context
    struct MealHistoryContext: Sendable {
        let mealTitle: String
        let outcome: String
        let weeksAgo: Int
    }
}

/// A meal suggestion with context hint for display
struct MealSuggestion: Identifiable, Sendable {
    let id: UUID
    let meal: Meal
    let reason: String

    init(meal: Meal, reason: String) {
        self.id = UUID()
        self.meal = meal
        self.reason = reason
    }
}

// MARK: - FoundationModelsService

/// Service for on-device AI operations using Foundation Models.
/// Requires iOS 26.0+.
@available(iOS 26.0, *)
@MainActor
class FoundationModelsService {

    // MARK: - Properties

    private var session: LanguageModelSession?

    /// Shared instance
    static let shared = FoundationModelsService()

    // MARK: - Initialization

    init() {}

    /// Initialize the language model session. Call before first use.
    func initialize() async throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw FoundationModelsError.unavailable
        }

        do {
            session = LanguageModelSession {
                """
                You are a helpful meal planning assistant. Your role is to suggest dinner alternatives \
                that work well for a household based on their patterns and context.

                When suggesting swaps:
                - Consider the day's busyness (busy days need easier meals)
                - Avoid duplicating meals already planned this week
                - Prioritize meals the household has kept in the past
                - Avoid meals that were frequently swapped or skipped
                - Match the general cuisine/protein variety of the week

                Keep responses concise and actionable.
                """
            }
        } catch {
            throw FoundationModelsError.sessionInitFailed(underlying: error)
        }
    }

    /// Check if Foundation Models are available on this device
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Swap Suggestions

    /// Generate 3 swap suggestions for a meal being replaced.
    func suggestSwaps(
        for currentMeal: Meal,
        context: SwapContext,
        availableMeals: [Meal]
    ) async throws -> [MealSuggestion] {
        if session == nil {
            try await initialize()
        }

        guard let session = session else {
            throw FoundationModelsError.unavailable
        }

        // Filter out unavailable meals
        let candidates = filterCandidates(
            from: availableMeals,
            excluding: currentMeal,
            context: context
        )

        guard candidates.count >= 3 else {
            // Return what we have if less than 3 candidates
            return candidates.prefix(3).map { meal in
                MealSuggestion(meal: meal, reason: "Available alternative")
            }
        }

        // Build prompt for Foundation Models
        let prompt = buildSwapPrompt(
            currentMeal: currentMeal,
            candidates: candidates,
            context: context
        )

        do {
            let response = try await session.respond(to: prompt)
            return parseSwapResponse(response.content, from: candidates)
        } catch {
            throw FoundationModelsError.generationFailed(underlying: error)
        }
    }

    // MARK: - Fuzzy Meal Matching

    /// Match free-text user input to a meal in the database.
    func matchMeal(
        userInput: String,
        availableMeals: [Meal]
    ) async throws -> Meal? {
        if session == nil {
            try await initialize()
        }

        guard let session = session else {
            return simpleStringMatch(userInput, in: availableMeals)
        }

        let mealList = availableMeals.map { "- \($0.title)" }.joined(separator: "\n")

        let prompt = """
            The user typed: "\(userInput)"

            Match this to ONE meal from the list below. If no good match exists, respond with "NO_MATCH".

            Available meals:
            \(mealList)

            Respond with ONLY the exact meal title from the list, or "NO_MATCH".
            """

        do {
            let response = try await session.respond(to: prompt)
            let matchedTitle = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            if matchedTitle == "NO_MATCH" {
                return nil
            }

            return availableMeals.first { $0.title.lowercased() == matchedTitle.lowercased() }
        } catch {
            // Fall back to simple string matching on error
            return simpleStringMatch(userInput, in: availableMeals)
        }
    }

    // MARK: - Prep Risk Inference

    /// Infer prep risk for a custom meal based on its name.
    func inferPrepRisk(forMealName name: String) async throws -> PrepRisk {
        if session == nil {
            try await initialize()
        }

        guard let session = session else {
            return .normal
        }

        let prompt = """
            Based on this meal name, estimate the prep difficulty:
            "\(name)"

            Respond with exactly one of: EASY, NORMAL, EFFORTFUL

            Guidelines:
            - EASY: Frozen food, sandwiches, simple reheating, takeout (<20 min)
            - NORMAL: Standard home cooking, 30-45 min prep
            - EFFORTFUL: Complex recipes, multiple components, 45+ min
            """

        do {
            let response = try await session.respond(to: prompt)
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            switch cleaned {
            case "EASY": return .fast
            case "NORMAL": return .normal
            case "EFFORTFUL": return .effortful
            default: return .normal
            }
        } catch {
            return .normal
        }
    }

    // MARK: - Private Helpers

    private func filterCandidates(
        from meals: [Meal],
        excluding currentMeal: Meal,
        context: SwapContext
    ) -> [Meal] {
        let otherMealTitles = Set(context.otherMealTitles.map { $0.lowercased() })

        return meals.filter { meal in
            // Exclude current meal
            guard meal.id != currentMeal.id else { return false }

            // Exclude hidden meals
            guard !meal.isHidden else { return false }

            // Exclude meals already in this week's plan
            guard !otherMealTitles.contains(meal.title.lowercased()) else { return false }

            // Apply dietary filters
            if context.glutenFree && meal.containsGluten { return false }
            if context.dairyFree && meal.containsDairy { return false }
            if context.nutFree && meal.containsNuts { return false }

            return true
        }
    }

    private func buildSwapPrompt(
        currentMeal: Meal,
        candidates: [Meal],
        context: SwapContext
    ) -> String {
        let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayName = dayNames[context.dayOfWeek]
        let busyStatus = context.isBusyDay ? "busy" : "normal"

        let candidateList = candidates.prefix(30).map { meal in
            "- \(meal.title) (\(meal.prepRisk.displayLabel), \(meal.cuisine ?? "varied"))"
        }.joined(separator: "\n")

        let weekMeals = context.otherMealTitles.joined(separator: ", ")

        let historyContext = context.recentHistory.prefix(20).map { item in
            "\(item.mealTitle): \(item.outcome) (\(item.weeksAgo)w ago)"
        }.joined(separator: ", ")

        return """
            User is swapping out "\(currentMeal.title)" on \(dayName) (\(busyStatus) day).

            Other meals this week: \(weekMeals.isEmpty ? "none yet" : weekMeals)

            Recent history: \(historyContext.isEmpty ? "none" : historyContext)

            Suggest exactly 3 alternatives from this list:
            \(candidateList)

            For each suggestion, respond in this format:
            1. [Meal Title] | [Brief reason, max 10 words]
            2. [Meal Title] | [Brief reason, max 10 words]
            3. [Meal Title] | [Brief reason, max 10 words]

            Prioritize:
            - Easy meals on busy days
            - Meals the household has kept before
            - Variety from what's already planned
            """
    }

    private func parseSwapResponse(
        _ response: String,
        from candidates: [Meal]
    ) -> [MealSuggestion] {
        var results: [MealSuggestion] = []

        let lines = response.components(separatedBy: "\n")
            .filter { $0.contains("|") }

        for line in lines.prefix(3) {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }

            // Extract meal title (remove leading number and punctuation)
            let titlePart = parts[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)

            let reason = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            // Find matching meal (case-insensitive)
            if let meal = candidates.first(where: { $0.title.lowercased() == titlePart.lowercased() }) {
                results.append(MealSuggestion(meal: meal, reason: reason))
            }
        }

        // Ensure we return exactly 3 (pad with remaining candidates if needed)
        if results.count < 3 {
            let remaining = candidates.filter { candidate in
                !results.contains { $0.meal.id == candidate.id }
            }
            for meal in remaining.prefix(3 - results.count) {
                results.append(MealSuggestion(meal: meal, reason: "Available alternative"))
            }
        }

        return Array(results.prefix(3))
    }

    private func simpleStringMatch(_ input: String, in meals: [Meal]) -> Meal? {
        let lowercasedInput = input.lowercased()

        // Exact match
        if let exact = meals.first(where: { $0.title.lowercased() == lowercasedInput }) {
            return exact
        }

        // Contains match
        if let contains = meals.first(where: { $0.title.lowercased().contains(lowercasedInput) }) {
            return contains
        }

        // Check tags
        return meals.first { meal in
            meal.tags.contains { $0.lowercased().contains(lowercasedInput) }
        }
    }
}
