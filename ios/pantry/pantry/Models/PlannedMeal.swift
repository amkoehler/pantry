//
//  PlannedMeal.swift
//  pantry
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

/// Represents a meal assignment for a specific day within a weekly plan.
@Model
class PlannedMeal {
    var id: UUID = UUID()

    /// Day of the week (1=Monday, 7=Sunday)
    var dayOfWeek: Int

    /// Whether user cleared this day ("Not cooking tonight")
    var isSkipped: Bool

    /// When this planned meal was created
    var createdAt: Date

    /// The assigned meal (nil if skipped)
    @Relationship
    var meal: Meal?

    /// The weekly plan this belongs to
    @Relationship
    var weeklyPlan: WeeklyPlan?

    /// The recorded outcome (kept/swapped/skipped)
    @Relationship(deleteRule: .cascade, inverse: \MealOutcome.plannedMeal)
    var outcome: MealOutcome?

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        isSkipped: Bool = false,
        createdAt: Date = Date(),
        meal: Meal? = nil,
        weeklyPlan: WeeklyPlan? = nil,
        outcome: MealOutcome? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.isSkipped = isSkipped
        self.createdAt = createdAt
        self.meal = meal
        self.weeklyPlan = weeklyPlan
        self.outcome = outcome
    }

    /// The actual calendar date for this planned meal (derived from week start + day of week)
    var calendarDate: Date? {
        guard let weekStart = weeklyPlan?.weekStartDate else { return nil }
        // dayOfWeek is 1=Monday, so Monday is weekStart + 0 days
        return Calendar.current.date(byAdding: .day, value: dayOfWeek - 1, to: weekStart)
    }

    /// Formatted date string like "1/6" for display
    var formattedDate: String? {
        guard let date = calendarDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Drag and Drop Support

extension UTType {
    /// Custom UTType for internal drag/drop of planned meals
    static var plannedMealID = UTType(exportedAs: "com.pantry.plannedmeal.id")
}

extension PlannedMeal: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}
