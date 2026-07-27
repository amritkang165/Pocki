import SwiftUI

extension View {
    /// Soft card shadow matching Apple’s elevated surfaces.
    func pockiShadow(radius: CGFloat = 16) -> some View {
        shadow(color: Color.black.opacity(0.06), radius: radius / 2, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.04), radius: radius, x: 0, y: 8)
    }

    /// Conditional modifier helper.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
