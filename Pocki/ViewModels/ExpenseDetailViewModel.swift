import Foundation
import Observation

/// Detail screen actions for a single expense.
@MainActor
@Observable
final class ExpenseDetailViewModel {
    let expense: Expense
    private let expenseService: ExpenseService

    init(expense: Expense, expenseService: ExpenseService) {
        self.expense = expense
        self.expenseService = expenseService
    }

    func delete() {
        expenseService.delete(expense)
        HapticService.warning()
    }
}
