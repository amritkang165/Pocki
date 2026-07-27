import SwiftUI

/// Always-visible circular FAB for adding expenses.
struct FloatingAddButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticService.mediumImpact()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: Constants.Layout.floatingButtonSize,
                    height: Constants.Layout.floatingButtonSize
                )
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.pockiAccent,
                                    Color.pockiAccent.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.pockiAccent.opacity(0.35), radius: 12, x: 0, y: 6)
                )
                .scaleEffect(isPressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add expense")
    }
}

#Preview {
    FloatingAddButton {}
}
