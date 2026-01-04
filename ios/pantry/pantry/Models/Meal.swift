//
//  Meal.swift
//  pantry
//

import Foundation
import SwiftData

/// Prep risk levels for meals, mapped from backend 'complexity' field.
/// - fast: 20-30 min (backend: "quick", UI: "Easy")
/// - normal: 30-45 min (backend: "normal", UI: "Normal")
/// - effortful: 45-75 min (backend: "long", not shown in v1)
enum PrepRisk: String, Codable {
    case fast
    case normal
    case effortful

    /// Display label for the UI
    var displayLabel: String {
        switch self {
        case .fast: return "Easy"
        case .normal: return "Normal"
        case .effortful: return "Effortful"
        }
    }

    /// Initialize from backend complexity value
    init(fromComplexity complexity: String) {
        switch complexity {
        case "quick": self = .fast
        case "normal": self = .normal
        case "long": self = .effortful
        default: self = .normal
        }
    }
}

/// Represents a meal, either cached from the backend API or user-created.
@Model
class Meal {
    var id: UUID = UUID()

    /// Backend meal ID for API correlation. Nil for custom meals.
    var serverId: Int?

    /// The meal name/title
    var title: String

    /// Prep risk level (Easy/Normal/Effortful)
    var prepRisk: PrepRisk

    /// Allergen flags for dietary filtering
    var containsGluten: Bool
    var containsDairy: Bool
    var containsNuts: Bool

    /// Whether this is a user-created custom meal
    var isCustom: Bool

    /// Whether user has hidden this meal via long-press
    var isHidden: Bool

    /// When the meal was created/cached
    var createdAt: Date

    // Additional backend fields for constraint matching

    /// Primary protein source (e.g., "chicken", "beef", "tofu")
    var protein: String?

    /// Cuisine type (e.g., "Italian", "Asian", "American")
    var cuisine: String?

    /// Tags for keyword search and constraint matching
    var tags: [String]

    init(
        id: UUID = UUID(),
        serverId: Int? = nil,
        title: String,
        prepRisk: PrepRisk = .normal,
        containsGluten: Bool = false,
        containsDairy: Bool = false,
        containsNuts: Bool = false,
        isCustom: Bool = false,
        isHidden: Bool = false,
        createdAt: Date = Date(),
        protein: String? = nil,
        cuisine: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.serverId = serverId
        self.title = title
        self.prepRisk = prepRisk
        self.containsGluten = containsGluten
        self.containsDairy = containsDairy
        self.containsNuts = containsNuts
        self.isCustom = isCustom
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.protein = protein
        self.cuisine = cuisine
        self.tags = tags
    }
}
