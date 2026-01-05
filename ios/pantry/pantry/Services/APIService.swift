import Foundation
import SwiftData

// MARK: - Request Types

struct DietaryFilters: Codable {
    let glutenFree: Bool
    let dairyFree: Bool
    let nutFree: Bool
}

struct MealHistoryItem: Codable {
    let mealTitle: String
    let outcome: String  // "kept", "swapped", "skipped"
    let weeksAgo: Int
}

struct DraftRequest: Codable {
    let dinnerCount: Int
    let busyDays: [Int]
    let constraints: String?
    let mealHistory: [MealHistoryItem]
    let dietaryFilters: DietaryFilters
}

// MARK: - Response Types

struct MealsResponse: Codable {
    let version: String
    let meals: [APIMeal]
    let count: Int
}

/// API response for a meal (distinct from SwiftData Meal model)
struct APIMeal: Codable {
    let id: Int
    let title: String
    let protein: String
    let starch: String?
    let vegOrFruit: [String]
    let cuisine: String
    let method: String
    let onePotOrPan: String
    let complexity: String  // "quick", "normal", "long"
    let estimatedTotalMinutes: Int
    let seasonality: String
    let containsGluten: Bool
    let containsDairy: Bool
    let containsNuts: Bool
    let tags: [String]
}

struct DraftResponse: Codable {
    let meals: [DraftMeal]
}

struct DraftMeal: Codable {
    let dayOfWeek: Int
    let mealId: Int?
    let mealTitle: String
    let reasoning: String?
}

struct ServerError: Codable {
    let error: String
}

// MARK: - API to Model Mapping

extension APIMeal {
    /// Convert API response to SwiftData Meal model
    func toMeal() -> Meal {
        Meal(
            serverId: id,
            title: title,
            prepRisk: PrepRisk(fromComplexity: complexity),
            containsGluten: containsGluten,
            containsDairy: containsDairy,
            containsNuts: containsNuts,
            isCustom: false,
            isHidden: false,
            createdAt: Date(),
            protein: protein,
            cuisine: cuisine,
            tags: tags
        )
    }
}

// MARK: - APIService

/// Service for communicating with the Pantry backend API.
/// Handles meal database sync and draft generation.
actor APIService {

    // MARK: - Configuration

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Shared instance with default configuration
    static let shared = APIService()

    /// Initialize with configurable base URL (useful for testing)
    init(
        baseURL: URL = URL(string: "http://localhost:3000")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - GET /api/meals

    /// Fetch meals from the backend API with dietary filters applied.
    func fetchMeals(
        glutenFree: Bool = false,
        dairyFree: Bool = false,
        nutFree: Bool = false
    ) async throws -> MealsResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/meals"),
            resolvingAgainstBaseURL: false
        )!

        var queryItems: [URLQueryItem] = []
        if glutenFree {
            queryItems.append(URLQueryItem(name: "gluten_free", value: "true"))
        }
        if dairyFree {
            queryItems.append(URLQueryItem(name: "dairy_free", value: "true"))
        }
        if nutFree {
            queryItems.append(URLQueryItem(name: "nut_free", value: "true"))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await performRequest(URLRequest(url: url))
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(MealsResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }

    // MARK: - POST /api/draft

    /// Generate a weekly draft from the backend AI.
    func generateDraft(request: DraftRequest) async throws -> DraftResponse {
        let url = baseURL.appendingPathComponent("api/draft")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw APIError.decodingError(underlying: error)
        }

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(DraftResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return // Success
        case 400..<500:
            if let serverError = try? decoder.decode(ServerError.self, from: data) {
                throw APIError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: serverError.error
                )
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        case 500..<600:
            if let serverError = try? decoder.decode(ServerError.self, from: data) {
                throw APIError.serverError(message: serverError.error)
            }
            throw APIError.serverError(message: "Internal server error")
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }
}

// MARK: - SwiftData Sync Extension

extension APIService {

    /// Sync meals from API to SwiftData, upserting by serverId.
    /// - Returns: Number of meals updated/inserted
    @discardableResult
    func syncMeals(
        to modelContext: ModelContext,
        preferences: UserPreferences
    ) async throws -> Int {
        // Fetch from API with user's dietary filters
        let response = try await fetchMeals(
            glutenFree: preferences.glutenFree,
            dairyFree: preferences.dairyFree,
            nutFree: preferences.nutFree
        )

        // Fetch existing meals from SwiftData for upsert
        let existingMeals = try modelContext.fetch(
            FetchDescriptor<Meal>(
                predicate: #Predicate { $0.serverId != nil }
            )
        )

        // Build lookup by serverId for O(1) upsert
        var existingByServerId: [Int: Meal] = [:]
        for meal in existingMeals {
            if let serverId = meal.serverId {
                existingByServerId[serverId] = meal
            }
        }

        var updatedCount = 0

        for apiMeal in response.meals {
            if let existingMeal = existingByServerId[apiMeal.id] {
                // Update existing meal (preserve isHidden and isCustom)
                existingMeal.title = apiMeal.title
                existingMeal.prepRisk = PrepRisk(fromComplexity: apiMeal.complexity)
                existingMeal.containsGluten = apiMeal.containsGluten
                existingMeal.containsDairy = apiMeal.containsDairy
                existingMeal.containsNuts = apiMeal.containsNuts
                existingMeal.protein = apiMeal.protein
                existingMeal.cuisine = apiMeal.cuisine
                existingMeal.tags = apiMeal.tags
            } else {
                // Insert new meal
                let newMeal = apiMeal.toMeal()
                modelContext.insert(newMeal)
            }
            updatedCount += 1
        }

        // Update sync timestamp
        preferences.lastMealSyncDate = Date()

        // Save changes
        try modelContext.save()

        return updatedCount
    }
}

// MARK: - Request Building Helpers

extension APIService {

    /// Build a DraftRequest from SwiftData models and user input.
    static func buildDraftRequest(
        dinnerCount: Int,
        weekShape: WeekShape,
        busyDays: [Int],
        constraints: String?,
        mealHistory: [PlannedMeal],
        preferences: UserPreferences
    ) -> DraftRequest {
        // Convert meal history to API format
        let historyItems: [MealHistoryItem] = mealHistory.compactMap { plannedMeal in
            guard let meal = plannedMeal.meal,
                  let outcome = plannedMeal.outcome,
                  let weeklyPlan = plannedMeal.weeklyPlan else {
                return nil
            }

            let weeksAgo = Calendar.current.dateComponents(
                [.weekOfYear],
                from: weeklyPlan.weekStartDate,
                to: Date()
            ).weekOfYear ?? 0

            // Only include last 8 weeks per spec
            guard weeksAgo <= 8 else { return nil }

            return MealHistoryItem(
                mealTitle: meal.title,
                outcome: outcome.outcome.rawValue,
                weeksAgo: weeksAgo
            )
        }

        // Apply week shape to busy days if no calendar access
        let effectiveBusyDays: [Int]
        if busyDays.isEmpty {
            switch weekShape {
            case .normal:
                effectiveBusyDays = []
            case .busy:
                effectiveBusyDays = [2, 4] // Tue, Thu assumed busy
            case .chaotic:
                effectiveBusyDays = [1, 2, 3, 4, 5] // All weekdays busy
            }
        } else {
            effectiveBusyDays = busyDays
        }

        return DraftRequest(
            dinnerCount: dinnerCount,
            busyDays: effectiveBusyDays,
            constraints: constraints,
            mealHistory: historyItems,
            dietaryFilters: DietaryFilters(
                glutenFree: preferences.glutenFree,
                dairyFree: preferences.dairyFree,
                nutFree: preferences.nutFree
            )
        )
    }
}
