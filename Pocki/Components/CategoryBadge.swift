import SwiftUI

/// Circular category icon with tinted background.
struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 40
    var showsLabel: Bool = false

    var body: some View {
        Group {
            if showsLabel {
                HStack(spacing: 8) {
                    iconView
                    Text(category.rawValue)
                        .font(.subheadline.weight(.medium))
                }
            } else {
                iconView
            }
        }
        .accessibilityLabel(category.rawValue)
    }

    private var iconView: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.14), in: Circle())
    }
}

#Preview {
    HStack {
        ForEach(ExpenseCategory.allCases.prefix(5)) { category in
            CategoryBadge(category: category)
        }
    }
    .padding()
}
