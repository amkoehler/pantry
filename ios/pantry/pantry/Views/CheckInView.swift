import SwiftUI
import SwiftData

/// Section below the weekly draft for configuring dinner count, week shape, and constraints.
struct CheckInView: View {
    @Bindable var weeklyPlan: WeeklyPlan
    var onRegenerateDraft: () -> Void

    @State private var regenerateTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Dinner count section
            DinnerCountSection(
                count: $weeklyPlan.dinnerCount,
                onChange: scheduleRegeneration
            )

            // Week shape section
            WeekShapeSection(
                shape: $weeklyPlan.weekShape,
                onChange: scheduleRegeneration
            )

            // Constraints section
            ConstraintsSection(
                constraints: $weeklyPlan.constraints,
                onSubmit: {
                    onRegenerateDraft()
                }
            )
        }
        .padding(.vertical, 8)
    }

    /// Debounce regeneration to avoid rapid API calls
    private func scheduleRegeneration() {
        regenerateTask?.cancel()
        regenerateTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled {
                await MainActor.run {
                    onRegenerateDraft()
                }
            }
        }
    }
}

// MARK: - Dinner Count Section

private struct DinnerCountSection: View {
    @Binding var count: Int
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planning for **\(count) dinner\(count == 1 ? "" : "s")** this week")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.primaryText)

            // Horizontal button strip: 1-7
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { num in
                    Button(action: {
                        if count != num {
                            count = num
                            onChange()
                        }
                    }) {
                        Text("\(num)")
                            .font(PantryTheme.Typography.body)
                            .fontWeight(count == num ? .semibold : .regular)
                            .frame(width: 36, height: 36)
                            .background(count == num ? PantryTheme.Colors.accent : PantryTheme.Colors.highlight)
                            .foregroundColor(count == num ? .white : PantryTheme.Colors.primaryText)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Week Shape Section

private struct WeekShapeSection: View {
    @Binding var shape: WeekShape
    var onChange: () -> Void

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
            .onChange(of: shape) { _, _ in
                onChange()
            }
        }
    }
}

// MARK: - Constraints Section

private struct ConstraintsSection: View {
    @Binding var constraints: String?
    var onSubmit: () -> Void

    @State private var localText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything to use up?")
                .font(PantryTheme.Typography.subheadline)
                .foregroundStyle(PantryTheme.Colors.primaryText)

            TextField("Chicken, frozen meals, etc.", text: $localText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    constraints = localText.isEmpty ? nil : localText
                    onSubmit()
                }
                .submitLabel(.done)
        }
        .onAppear {
            localText = constraints ?? ""
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
