import SwiftUI
import Combine

/// Cooking-themed loading spinner with rotating messages.
/// Used during draft regeneration to provide whimsical feedback.
struct CookingSpinner: View {
    @State private var messageCycler = MessageCycler.cooking()

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(PantryTheme.Colors.accent)

            Text(messageCycler.currentMessage)
                .font(PantryTheme.Typography.headline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: messageCycler.currentIndex)
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { _ in
            withAnimation {
                messageCycler.advance()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CookingSpinner()
}
