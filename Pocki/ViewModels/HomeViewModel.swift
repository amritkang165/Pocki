import Foundation
import SwiftData
import Observation

/// Aggregates home-screen spending metrics.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var greeting: String = ""
    private(set) var monthSpent: Double = 0
    private(set) var todaySpent: Double = 0
    private(set) var weekSpent: Double = 0
    private(set) var dailyAverage: Double = 0
    private(set) var recentExpenses: [Expense] = []
    private(set) var budget: Double = Constants.Budget.defaultMonthly
    private(set) var currencyCode: String = "USD"
    private(set) var monthLabel: String = Date.now.monthYearLabel
    private(set) var selectedMonth: Date = Date.now.startOfMonth

    var remaining: Double { budget - monthSpent }
    var progress: Double {
        guard budget > 0 else { return 0 }
        return monthSpent / budget
    }

    var canGoToNextMonth: Bool {
        selectedMonth < Date.now.startOfMonth
    }

    private var expenses: [Expense] = []
    private var settings: AppSettings?
    private let budgetService: BudgetService

    init(budgetService: BudgetService) {
        self.budgetService = budgetService
        refreshGreeting()
    }

    /// Recomputes metrics from the latest expense list and settings.
    func refresh(expenses: [Expense], settings: AppSettings) {
        self.expenses = expenses
        self.settings = settings
        recompute()
    }

    /// Moves the budget card to the previous month.
    func goToPreviousMonth() {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = previous.startOfMonth
        recompute()
    }

    /// Moves the budget card to the next month (never beyond the current one).
    func goToNextMonth() {
        guard canGoToNextMonth,
              let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = next.startOfMonth
        recompute()
    }

    private func recompute() {
        guard let settings else { return }
        budget = settings.monthlyBudget
        currencyCode = settings.currencyCode
        monthLabel = selectedMonth.monthYearLabel
        refreshGreeting()

        let calendar = Calendar.current
        let now = Date.now

        monthSpent = expenses
            .filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }

        todaySpent = expenses
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }

        let weekStart = now.startOfWeek
        weekSpent = expenses
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.amount }

        let anchor = min(now, selectedMonth.endOfMonth)
        let dayOfMonth = max(calendar.component(.day, from: anchor), 1)
        dailyAverage = monthSpent / Double(dayOfMonth)

        recentExpenses = Array(
            expenses
                .sorted { $0.date > $1.date }
                .prefix(5)
        )
    }

    private func refreshGreeting() {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        case 17..<22: greeting = "Good evening"
        default: greeting = "Good night"
        }
    }
}
