import SwiftUI

/// List row representing a single expense.
struct ExpenseRow: View {
    let expense: Expense
    let currencyCode: String

    var body: some View {
        HStack(spacing: 14) {
            CategoryBadge(category: expense.category, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(expense.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount.formatted(currencyCode: currencyCode))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)

                Text(expense.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.merchant), \(expense.category.rawValue), \(expense.amount.formatted(currencyCode: currencyCode))")
    }
}

#Preview {
    List {
        ExpenseRow(
            expense: Expense(amount: 12.5, merchant: "Blue Bottle", category: .food),
            currencyCode: "USD"
        )
    }
}
