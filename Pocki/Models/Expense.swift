import Foundation
import SwiftData

/// A single spending record persisted with SwiftData.
@Model
final class Expense: Identifiable {
    var id: UUID
    var amount: Double
    var merchant: String
    var categoryRaw: String
    var date: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Future-ready fields

    var sourceRaw: String
    var isVerified: Bool
    var confidence: Double?

    /// Typed category accessor.
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Typed source accessor.
    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        merchant: String,
        category: ExpenseCategory,
        date: Date = .now,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        source: ExpenseSource = .manual,
        isVerified: Bool = true,
        confidence: Double? = nil
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.categoryRaw = category.rawValue
        self.date = date
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceRaw = source.rawValue
        self.isVerified = isVerified
        self.confidence = confidence
    }
}
