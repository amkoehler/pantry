import SwiftUI
import Combine

/// Full-screen cooking-themed loading spinner with rotating messages.
/// Used during draft regeneration to provide whimsical feedback.
struct CookingSpinner: View {
    @State private var currentMessage = 0

    private let messages = [
        "Sautéing...",
        "Simmering...",
        "Toasting...",
        "Chopping...",
        "Whisking...",
        "Seasoning..."
    ]

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(PantryTheme.Colors.accent)

            Text(messages[currentMessage])
                .font(PantryTheme.Typography.headline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: currentMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PantryTheme.Colors.background.opacity(0.95))
        .onReceive(timer) { _ in
            withAnimation {
                currentMessage = (currentMessage + 1) % messages.count
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CookingSpinner()
}
