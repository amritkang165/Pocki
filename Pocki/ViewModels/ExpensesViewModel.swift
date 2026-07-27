import Foundation
import Observation

/// Powers the expenses list with search and grouping.
@MainActor
@Observable
final class ExpensesViewModel {
    var searchText: String = ""

    private let expenseService: ExpenseService

    init(expenseService: ExpenseService) {
        self.expenseService = expenseService
    }

    /// Returns expenses filtered by the current search query.
    func filtered(_ expenses: [Expense]) -> [Expense] {
        expenseService.search(searchText, in: expenses)
    }

    /// Groups expenses by calendar day for sectioned lists.
    func groupedByDate(_ expenses: [Expense]) -> [(key: Date, expenses: [Expense])] {
        let filtered = filtered(expenses)
        let grouped = Dictionary(grouping: filtered) { $0.date.startOfDay }
        return grouped
            .map { (key: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.key > $1.key }
    }

    func delete(_ expense: Expense) {
        expenseService.delete(expense)
        HapticService.lightImpact()
    }
}
