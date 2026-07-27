import Foundation
import SwiftData

/// Manages monthly budget preferences and derived metrics.
@MainActor
final class BudgetService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Returns existing settings or creates defaults.
    func loadSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        modelContext.insert(settings)
        save()
        return settings
    }

    /// Persists a new monthly budget amount.
    func updateBudget(_ amount: Double, settings: AppSettings) {
        settings.monthlyBudget = max(0, amount)
        settings.updatedAt = .now
        save()
    }

    /// Persists the preferred currency code.
    func updateCurrency(_ code: String, settings: AppSettings) {
        settings.currencyCode = code
        settings.updatedAt = .now
        save()
    }

    /// Spent total for the given month.
    func spent(in expenses: [Expense], monthOf date: Date = .now) -> Double {
        expenses
            .filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Remaining budget for the month (clamped at zero for display convenience elsewhere).
    func remaining(budget: Double, spent: Double) -> Double {
        budget - spent
    }

    /// Progress from 0…1+ (can exceed 1 when over budget).
    func progress(budget: Double, spent: Double) -> Double {
        guard budget > 0 else { return spent > 0 ? 1 : 0 }
        return spent / budget
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save settings: \(error)")
        }
    }
}
