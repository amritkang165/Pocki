import SwiftUI

/// Compact statistic tile for home and insights.
struct StatCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    var accent: Color = .pockiAccent

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let icon {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .frame(width: 28, height: 28)
                            .background(accent.opacity(0.12), in: Circle())
                    }
                    Spacer(minLength: 0)
                }

                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        StatCard(title: "Today", value: "$62", icon: "sun.max.fill")
        StatCard(title: "This Week", value: "$214", icon: "calendar", accent: .pockiWarning)
    }
    .padding()
    .background(PockiBackground())
}
