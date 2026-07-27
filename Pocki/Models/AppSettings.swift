import Foundation
import SwiftData

/// User preferences persisted locally. Designed for future CloudKit sync.
@Model
final class AppSettings {
    var id: UUID
    var monthlyBudget: Double
    var currencyCode: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        monthlyBudget: Double = 2000,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.monthlyBudget = monthlyBudget
        self.currencyCode = currencyCode
        self.updatedAt = updatedAt
    }
}
