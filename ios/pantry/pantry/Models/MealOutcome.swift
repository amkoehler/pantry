//
//  MealOutcome.swift
//  pantry
//

import Foundation
import SwiftData

/// Records what happened with a planned meal.
/// Used to build meal history for draft generation.
enum Outcome: String, Codable {
    /// No action taken - silence is assumed kept
    case kept

    /// User selected an alternative meal
    case swapped

    /// User cleared the day ("Not cooking tonight")
    case skipped
}

/// Records the outcome of a planned meal for history tracking.
@Model
class MealOutcome {
    var id: UUID = UUID()

    /// What happened to the meal
    var outcome: Outcome

    /// When the outcome was recorded
    var recordedAt: Date

    /// The planned meal this outcome belongs to
    @Relationship
    var plannedMeal: PlannedMeal?

    init(
        id: UUID = UUID(),
        outcome: Outcome,
        recordedAt: Date = Date(),
        plannedMeal: PlannedMeal? = nil
    ) {
        self.id = id
        self.outcome = outcome
        self.recordedAt = recordedAt
        self.plannedMeal = plannedMeal
    }
}
