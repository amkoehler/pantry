import SwiftUI

/// A card displaying a single planned meal for a day in the weekly view.
/// Tapping the card opens the swap sheet.
struct DayCardView: View {
    let plannedMeal: PlannedMeal
    let onTap: () -> Void

    private var dayName: String {
        WeeklyPlanViewModel.dayName(for: plannedMeal.dayOfWeek)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Day label
                Text(dayName)
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.secondaryText)

                // Meal content or cleared state
                if plannedMeal.isSkipped {
                    Text("Not cooking tonight")
                        .font(PantryTheme.Typography.body)
                        .foregroundStyle(PantryTheme.Colors.tertiaryText)
                        .italic()
                } else if let meal = plannedMeal.meal {
                    HStack(alignment: .center) {
                        Text(meal.title)
                            .font(PantryTheme.Typography.headline)
                            .foregroundStyle(PantryTheme.Colors.primaryText)

                        Spacer()

                        // Prep risk tag (only show "Easy" for fast meals)
                        if meal.prepRisk == .fast {
                            PrepBadge(label: "Easy")
                        }
                    }
                } else {
                    // No meal assigned yet
                    Text("Tap to add")
                        .font(PantryTheme.Typography.body)
                        .foregroundStyle(PantryTheme.Colors.tertiaryText)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PantryTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.card))
            .shadow(color: PantryTheme.Colors.primaryText.opacity(0.06), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(DayCardButtonStyle())
    }
}

// MARK: - Prep Badge

/// Small badge indicating meal prep difficulty
struct PrepBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(PantryTheme.Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(PantryTheme.Colors.secondaryAccent.opacity(0.15))
            .foregroundStyle(PantryTheme.Colors.secondaryAccent)
            .clipShape(Capsule())
    }
}

// MARK: - Custom Button Style

/// Subtle press animation for day cards
struct DayCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Normal Meal") {
    let meal = Meal(title: "Chicken Stir Fry", prepRisk: .fast)
    let plannedMeal = PlannedMeal(dayOfWeek: 1, meal: meal)

    DayCardView(plannedMeal: plannedMeal, onTap: {})
        .padding()
        .background(PantryTheme.Colors.background)
}

#Preview("Skipped Day") {
    let plannedMeal = PlannedMeal(dayOfWeek: 3, isSkipped: true)

    DayCardView(plannedMeal: plannedMeal, onTap: {})
        .padding()
        .background(PantryTheme.Colors.background)
}
