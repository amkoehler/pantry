//
//  WeeklyPlan.swift
//  pantry
//

import Foundation
import SwiftData

/// Describes the overall busyness of a week.
/// Used when calendar access is unavailable for per-day detection.
enum WeekShape: String, Codable {
    /// Normal week, default difficulty
    case normal

    /// Busy week, prefer easier meals overall
    case busy

    /// Chaotic week, strongly prefer easy/quick meals
    case chaotic
}

/// Container for a week's dinner plan.
@Model
class WeeklyPlan {
    var id: UUID = UUID()

    /// Monday of this week (used as the week identifier)
    var weekStartDate: Date

    /// Overall busyness level for the week
    var weekShape: WeekShape

    /// Number of dinners planned (1-7), typically 5
    var dinnerCount: Int

    /// User constraints like "use up chicken" or "frozen meals"
    var constraints: String?

    /// Whether user exported/shared this plan (soft commitment signal)
    var exported: Bool

    /// When this plan was created
    var createdAt: Date

    /// The individual meal assignments for this week
    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weeklyPlan)
    var plannedMeals: [PlannedMeal]?

    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        weekShape: WeekShape = .normal,
        dinnerCount: Int = 5,
        constraints: String? = nil,
        exported: Bool = false,
        createdAt: Date = Date(),
        plannedMeals: [PlannedMeal]? = nil
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekShape = weekShape
        self.dinnerCount = dinnerCount
        self.constraints = constraints
        self.exported = exported
        self.createdAt = createdAt
        self.plannedMeals = plannedMeals
    }
}
