import Foundation
import Observation

/// Chart-ready aggregates for the Insights tab.
@MainActor
@Observable
final class InsightsViewModel {
    struct DaySpend: Identifiable {
        let id: Date
        let date: Date
        let amount: Double
    }

    struct CategorySpend: Identifiable {
        let id: ExpenseCategory
        let category: ExpenseCategory
        let amount: Double
        var percentage: Double
    }

    struct MerchantSpend: Identifiable {
        let id: String
        let merchant: String
        let amount: Double
        let count: Int
    }

    private(set) var weekly: [DaySpend] = []
    private(set) var monthly: [DaySpend] = []
    private(set) var categories: [CategorySpend] = []
    private(set) var topMerchants: [MerchantSpend] = []
    private(set) var dailyAverage: Double = 0
    private(set) var monthTotal: Double = 0
    private(set) var weekTotal: Double = 0
    private(set) var trendDelta: Double = 0
    private(set) var currencyCode: String = "USD"

    /// Rebuilds all chart datasets from expenses.
    func refresh(expenses: [Expense], currencyCode: String) {
        self.currencyCode = currencyCode
        let calendar = Calendar.current
        let now = Date.now

        weekly = calendar.lastDays(7).map { day in
            let amount = expenses
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return DaySpend(id: day, date: day, amount: amount)
        }
        weekTotal = weekly.reduce(0) { $0 + $1.amount }

        let monthStart = now.startOfMonth
        let daysInMonthSoFar = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 0
        monthly = (0...daysInMonthSoFar).compactMap { offset -> DaySpend? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
            let amount = expenses
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return DaySpend(id: day, date: day, amount: amount)
        }
        monthTotal = monthly.reduce(0) { $0 + $1.amount }

        let dayOfMonth = max(calendar.component(.day, from: now), 1)
        dailyAverage = monthTotal / Double(dayOfMonth)

        let monthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }

        let categoryTotals = Dictionary(grouping: monthExpenses, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        categories = categoryTotals
            .map { CategorySpend(id: $0.key, category: $0.key, amount: $0.value, percentage: 0) }
            .sorted { $0.amount > $1.amount }
        let catSum = categories.reduce(0) { $0 + $1.amount }
        categories = categories.map {
            CategorySpend(
                id: $0.id,
                category: $0.category,
                amount: $0.amount,
                percentage: catSum > 0 ? $0.amount / catSum : 0
            )
        }

        let merchantGroups = Dictionary(grouping: monthExpenses, by: \.merchant)
        topMerchants = merchantGroups
            .map { key, value in
                MerchantSpend(
                    id: key,
                    merchant: key,
                    amount: value.reduce(0) { $0 + $1.amount },
                    count: value.count
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }

        // Compare this week vs previous week.
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: now.startOfWeek) ?? now
        let previousWeekEnd = now.startOfWeek
        let previousWeekTotal = expenses
            .filter { $0.date >= previousWeekStart && $0.date < previousWeekEnd }
            .reduce(0) { $0 + $1.amount }
        trendDelta = weekTotal - previousWeekTotal
    }
}
