import SwiftUI
import SwiftData

/// Section below the weekly draft for configuring week shape and constraints.
struct CheckInView: View {
    @Bindable var weeklyPlan: WeeklyPlan
    var onRegenerateDraft: () -> Void

    // Track dirty state for explicit "Update Plan" button
    @State private var localWeekShape: WeekShape = .normal
    @State private var lastAppliedWeekShape: WeekShape = .normal
    @State private var localConstraints: String = ""
    @State private var lastAppliedConstraints: String = ""

    var hasUnappliedChanges: Bool {
        localWeekShape != lastAppliedWeekShape || localConstraints != lastAppliedConstraints
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Week shape section
            WeekShapeSection(shape: $localWeekShape)

            // Constraints section
            ConstraintsSection(
                localText: $localConstraints
            )

            // Sticky footer with "Update Plan" button
            if hasUnappliedChanges {
                Button(action: applyChanges) {
                    Text("Update Plan")
                        .font(PantryTheme.Typography.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PantryTheme.Colors.accent)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            // Initialize local state from model
            localWeekShape = weeklyPlan.weekShape
            lastAppliedWeekShape = localWeekShape
            localConstraints = weeklyPlan.constraints ?? ""
            lastAppliedConstraints = localConstraints
        }
    }

    /// Apply changes and trigger regeneration
    private func applyChanges() {
        weeklyPlan.weekShape = localWeekShape
        lastAppliedWeekShape = localWeekShape
        weeklyPlan.constraints = localConstraints.isEmpty ? nil : localConstraints
        lastAppliedConstraints = localConstraints
        onRegenerateDraft()
    }
}

// MARK: - Week Shape Section

private struct WeekShapeSection: View {
    @Binding var shape: WeekShape

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What kind of week is it?")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.primaryText)

            Picker("Week Shape", selection: $shape) {
                Text("Normal").tag(WeekShape.normal)
                Text("Busy").tag(WeekShape.busy)
                Text("Chaotic").tag(WeekShape.chaotic)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Constraints Section

private struct ConstraintsSection: View {
    @Binding var localText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything to use up?")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.primaryText)

            TextField("Chicken, frozen meals, etc.", text: $localText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
        }
    }
}

// MARK: - Preview

#Preview {
    let weeklyPlan = WeeklyPlan(
        weekStartDate: Date(),
        weekShape: .normal,
        dinnerCount: 5
    )

    ScrollView {
        CheckInView(weeklyPlan: weeklyPlan) {
            print("Regenerate draft")
        }
        .padding()
    }
    .background(PantryTheme.Colors.background)
}
