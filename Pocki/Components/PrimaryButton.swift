import SwiftUI

/// Full-width primary call-to-action button.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.buttonRadius, style: .continuous)
                    .fill(isEnabled ? Color.pockiAccent : Color.pockiAccent.opacity(0.4))
            )
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

/// Subtle press scale for primary controls.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    PrimaryButton(title: "Save Expense") {}
        .padding()
}
