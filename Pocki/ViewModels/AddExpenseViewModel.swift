import Foundation
import Observation

/// Form state and validation for creating or editing an expense.
@MainActor
@Observable
final class AddExpenseViewModel {
    var amountText: String = ""
    var merchant: String = ""
    var category: ExpenseCategory = .food
    var date: Date = .now
    var note: String = ""

    var editingExpense: Expense?

    private let expenseService: ExpenseService

    init(expenseService: ExpenseService, editingExpense: Expense? = nil) {
        self.expenseService = expenseService
        self.editingExpense = editingExpense
        if let editingExpense {
            load(from: editingExpense)
        }
    }

    var isEditing: Bool { editingExpense != nil }

    var parsedAmount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var isValid: Bool {
        parsedAmount != nil && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var title: String { isEditing ? "Edit Expense" : "Add Expense" }
    var saveTitle: String { isEditing ? "Save Changes" : "Save Expense" }

    func load(from expense: Expense) {
        amountText = expense.amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(expense.amount))
            : String(format: "%.2f", expense.amount)
        merchant = expense.merchant
        category = expense.category
        date = expense.date
        note = expense.note ?? ""
    }

    @discardableResult
    func save() -> Bool {
        guard let amount = parsedAmount else { return false }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else { return false }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingExpense {
            editingExpense.amount = amount
            editingExpense.merchant = trimmedMerchant
            editingExpense.category = category
            editingExpense.date = date
            editingExpense.note = trimmedNote.isEmpty ? nil : trimmedNote
            expenseService.update(editingExpense)
        } else {
            let expense = Expense(
                amount: amount,
                merchant: trimmedMerchant,
                category: category,
                date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                source: .manual,
                isVerified: true
            )
            expenseService.create(expense)
        }

        HapticService.success()
        return true
    }
}
