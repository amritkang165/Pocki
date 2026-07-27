import SwiftUI

/// Frosted, elevated card surface used across Pocki screens.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = Constants.Layout.cardRadius
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.pockiCard.opacity(0.55))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
            .pockiShadow()
    }
}

#Preview {
    GlassCard {
        Text("Hello, Pocki")
            .font(.headline)
    }
    .padding()
    .background(PockiBackground())
}
