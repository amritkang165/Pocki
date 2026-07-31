import Foundation
import SwiftData

/// CRUD and query operations for expenses.
@MainActor
final class ExpenseService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a new expense.
    func create(_ expense: Expense) {
        modelContext.insert(expense)
        save()
    }

    /// Inserts a batch of expenses, skipping any that already exist in the store
    /// (same amount, same merchant, same calendar day). Returns how many were
    /// skipped so callers can tell the user what happened.
    @discardableResult
    func createIfMissing(_ expenses: [Expense]) -> Int {
        guard !expenses.isEmpty else { return 0 }

        var existing = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        var skipped = 0

        for expense in expenses {
            let isDuplicate = existing.contains { candidate in
                abs(candidate.amount - expense.amount) < 0.005
                    && candidate.merchant.lowercased() == expense.merchant.lowercased()
                    && Calendar.current.isDate(candidate.date, inSameDayAs: expense.date)
            }
            if isDuplicate {
                skipped += 1
            } else {
                modelContext.insert(expense)
                existing.append(expense)
            }
        }

        save()
        return skipped
    }

    /// Updates an existing expense and stamps `updatedAt`.
    func update(_ expense: Expense) {
        expense.updatedAt = .now
        save()
    }

    /// Deletes an expense.
    func delete(_ expense: Expense) {
        modelContext.delete(expense)
        save()
    }

    /// Deletes multiple expenses.
    func delete(_ expenses: [Expense]) {
        expenses.forEach { modelContext.delete($0) }
        save()
    }

    /// Removes every expense from the store.
    func deleteAll() throws {
        try modelContext.delete(model: Expense.self)
        save()
    }

    /// Fetches all expenses sorted by date descending.
    func fetchAll() throws -> [Expense] {
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Filters expenses whose merchant, category, or notes contain the query.
    func search(_ query: String, in expenses: [Expense]) -> [Expense] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return expenses }
        let lower = trimmed.lowercased()
        return expenses.filter { expense in
            expense.merchant.lowercased().contains(lower)
                || expense.category.rawValue.lowercased().contains(lower)
                || (expense.note?.lowercased().contains(lower) ?? false)
        }
    }

    // MARK: - Merchant category memory

    /// Category to suggest for a merchant: what the user last chose for it
    /// first, then keyword heuristics. Returns nil when both are unknown.
    func suggestedCategory(for merchant: String?) -> ExpenseCategory? {
        guard let merchant else { return nil }
        let normalized = normalizedMerchant(merchant)
        if let record = fetchMerchantRecord(normalized) {
            return record.category
        }
        return MerchantCategorizer.heuristic(for: merchant)
    }

    /// Records the user's final category for a merchant so future entries
    /// suggest the same category. Upserts the memory row and bumps its count.
    func rememberCategory(for merchant: String?, category: ExpenseCategory) {
        guard let merchant else { return }
        let normalized = normalizedMerchant(merchant)
        if let record = fetchMerchantRecord(normalized) {
            record.category = category
            record.usageCount += 1
            record.lastUsed = .now
        } else {
            modelContext.insert(MerchantCategory(merchant: normalized, category: category))
        }
        save()
    }

    private func fetchMerchantRecord(_ normalized: String) -> MerchantCategory? {
        let descriptor = FetchDescriptor<MerchantCategory>(
            predicate: #Predicate { $0.merchant == normalized }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func normalizedMerchant(_ merchant: String) -> String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save expenses: \(error)")
        }
    }
}
