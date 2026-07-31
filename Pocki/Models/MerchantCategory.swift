import Foundation
import SwiftData

/// Remembers which category the user last chose for a merchant, so future
/// imports and manual entries can suggest the same category again.
@Model
final class MerchantCategory: Identifiable {
    /// Normalized (lowercased, trimmed) merchant name this record applies to.
    var merchant: String
    var categoryRaw: String
    var usageCount: Int
    var lastUsed: Date

    init(
        merchant: String,
        category: ExpenseCategory,
        usageCount: Int = 1,
        lastUsed: Date = .now
    ) {
        self.merchant = merchant
        self.categoryRaw = category.rawValue
        self.usageCount = usageCount
        self.lastUsed = lastUsed
    }

    /// Typed category accessor.
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
