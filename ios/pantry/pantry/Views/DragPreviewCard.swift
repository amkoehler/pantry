//
//  DragPreviewCard.swift
//  pantry
//

import SwiftUI

/// Lightweight preview card shown during drag operation.
struct DragPreviewCard: View {
    let plannedMeal: PlannedMeal

    private var dayName: String {
        WeeklyPlanViewModel.dayName(for: plannedMeal.dayOfWeek)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayName)
                .font(PantryTheme.Typography.caption)
                .foregroundStyle(PantryTheme.Colors.secondaryText)

            if plannedMeal.isSkipped {
                Text("Not cooking")
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.tertiaryText)
                    .italic()
            } else if let meal = plannedMeal.meal {
                Text(meal.title)
                    .font(PantryTheme.Typography.headline)
                    .foregroundStyle(PantryTheme.Colors.primaryText)
            } else {
                Text("Empty")
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.tertiaryText)
                    .italic()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
                .fill(PantryTheme.Colors.cardBackground)
        )
        .contentShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.card))
        .drawingGroup()
    }
}
