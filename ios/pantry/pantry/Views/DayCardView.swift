import SwiftUI
import UIKit

/// A card displaying a single planned meal for a day in the weekly view.
/// Tapping the card opens the swap sheet. Long-press to drag and swap with another day.
struct DayCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let plannedMeal: PlannedMeal
    @Binding var draggedMeal: PlannedMeal?
    let onTap: () -> Void
    let onDrop: (PlannedMeal) -> Void

    @State private var isDropTargeted = false

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
                            .font(PantryTheme.Typography.title)
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
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.15)
                    : Color.black.opacity(0.06),
                radius: colorScheme == .dark ? 4 : 6,
                y: 2
            )
        }
        .buttonStyle(DayCardButtonStyle())
        // Drag source - long press to initiate
        .onDrag {
            draggedMeal = plannedMeal
            return NSItemProvider(object: plannedMeal.id.uuidString as NSString)
        } preview: {
            DragPreviewCard(plannedMeal: plannedMeal)
        }
        // Drop target - accept String (the UUID from Transferable)
        .dropDestination(for: String.self) { _, _ in
            guard let source = draggedMeal,
                  source.id != plannedMeal.id else { return false }
            onDrop(source)
            return true
        } isTargeted: { targeted in
            // Don't highlight if dropping on self
            let shouldHighlight = targeted && draggedMeal?.id != plannedMeal.id
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = shouldHighlight
            }
            if shouldHighlight {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        // Drop target visual feedback
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(PantryTheme.Colors.accent)
            }
        }
        .background {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
                    .fill(PantryTheme.Colors.highlight.opacity(0.3))
            }
        }
    }
}

// MARK: - Prep Badge

/// Small badge indicating meal prep difficulty
struct PrepBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .badgeStyle()
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
    @Previewable @State var draggedMeal: PlannedMeal?
    let meal = Meal(title: "Chicken Stir Fry", prepRisk: .fast)
    let plannedMeal = PlannedMeal(dayOfWeek: 1, meal: meal)

    DayCardView(plannedMeal: plannedMeal, draggedMeal: $draggedMeal, onTap: {}, onDrop: { _ in })
        .padding()
        .background(PantryTheme.Colors.background)
}

#Preview("Skipped Day") {
    @Previewable @State var draggedMeal: PlannedMeal?
    let plannedMeal = PlannedMeal(dayOfWeek: 3, isSkipped: true)

    DayCardView(plannedMeal: plannedMeal, draggedMeal: $draggedMeal, onTap: {}, onDrop: { _ in })
        .padding()
        .background(PantryTheme.Colors.background)
}
