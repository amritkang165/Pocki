import SwiftUI

extension Color {
    /// Primary brand accent — calm teal, Wallet-inspired.
    static let pockiAccent = Color(red: 0.15, green: 0.68, blue: 0.62)

    /// Secondary accent for progress and positive states.
    static let pockiSuccess = Color(red: 0.30, green: 0.78, blue: 0.55)

    /// Warning / over-budget tint.
    static let pockiWarning = Color(red: 0.95, green: 0.55, blue: 0.30)

    /// Soft card fill that adapts to light and dark mode.
    static let pockiCard = Color(.secondarySystemGroupedBackground)

    /// Subtle separator / hairline.
    static let pockiSeparator = Color(.separator)
}

/// Adaptive background gradient for the app chrome.
struct PockiBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.09, green: 0.11, blue: 0.13),
                    Color(red: 0.06, green: 0.09, blue: 0.10)
                ]
                : [
                    Color(red: 0.96, green: 0.97, blue: 0.98),
                    Color(red: 0.93, green: 0.96, blue: 0.96),
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
