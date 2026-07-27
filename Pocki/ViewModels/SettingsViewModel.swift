import Foundation
import Observation
import SwiftData

/// Settings screen state and destructive actions.
@MainActor
@Observable
final class SettingsViewModel {
    var budgetText: String = ""
    var selectedCurrency: String = "USD"
    var showResetConfirmation: Bool = false
    var showExportPlaceholder: Bool = false

    let availableCurrencies = ["USD", "EUR", "GBP", "INR", "CAD", "AUD", "JPY", "CHF"]

    private let budgetService: BudgetService
    private let expenseService: ExpenseService
    private(set) var settings: AppSettings?

    init(budgetService: BudgetService, expenseService: ExpenseService) {
        self.budgetService = budgetService
        self.expenseService = expenseService
    }

    func load() {
        let loaded = budgetService.loadSettings()
        settings = loaded
        selectedCurrency = loaded.currencyCode
        budgetText = loaded.monthlyBudget.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(loaded.monthlyBudget))
            : String(format: "%.2f", loaded.monthlyBudget)
    }

    func saveBudget() {
        guard let settings,
              let value = Double(budgetText.replacingOccurrences(of: ",", with: ".")),
              value >= 0 else { return }
        budgetService.updateBudget(value, settings: settings)
        HapticService.success()
    }

    func saveCurrency() {
        guard let settings else { return }
        budgetService.updateCurrency(selectedCurrency, settings: settings)
        HapticService.selection()
    }

    func resetAllData() throws {
        try expenseService.deleteAll()
        if let settings {
            budgetService.updateBudget(Constants.Budget.defaultMonthly, settings: settings)
            budgetText = String(Int(Constants.Budget.defaultMonthly))
        }
        HapticService.warning()
    }
}
