import SwiftUI

/// Hero budget summary with animated progress ring.
struct BudgetCard: View {
    let spent: Double
    let budget: Double
    let currencyCode: String
    let monthLabel: String

    private var remaining: Double { budget - spent }
    private var progress: Double {
        guard budget > 0 else { return 0 }
        return spent / budget
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Monthly Budget")
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                }

                ZStack {
                    ProgressRing(
                        progress: progress,
                        lineWidth: 16,
                        size: 168,
                        progressColor: progress > 1 ? .pockiWarning : .pockiAccent
                    )

                    VStack(spacing: 4) {
                        Text(spent.formatted(currencyCode: currencyCode))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 120)
                }

                HStack(spacing: 0) {
                    metric(
                        title: "Remaining",
                        value: max(remaining, 0).formatted(currencyCode: currencyCode),
                        tint: remaining >= 0 ? .pockiSuccess : .pockiWarning
                    )
                    Divider()
                        .frame(height: 36)
                    metric(
                        title: "Budget",
                        value: budget.formatted(currencyCode: currencyCode),
                        tint: .primary
                    )
                    Divider()
                        .frame(height: 36)
                    metric(
                        title: "Used",
                        value: "\(Int(min(progress, 9.99) * 100))%",
                        tint: progress > Constants.Budget.warningThreshold ? .pockiWarning : .pockiAccent
                    )
                }
            }
        }
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BudgetCard(
        spent: 1240,
        budget: 2000,
        currencyCode: "USD",
        monthLabel: "July 2026"
    )
    .padding()
    .background(PockiBackground())
}
