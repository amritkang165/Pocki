import SwiftUI

/// Polished empty-state placeholder with optional CTA.
struct EmptyStateView: View {
    let title: String
    var message: String? = nil
    var systemImage: String = "tray"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.pockiAccent.opacity(0.85))
                .frame(width: 96, height: 96)
                .background(
                    Circle()
                        .fill(Color.pockiAccent.opacity(0.1))
                )
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView(
        title: "No expenses yet",
        message: "Track your first purchase and Pocki will do the rest.",
        systemImage: "creditcard",
        actionTitle: "Add your first expense"
    ) {}
}
