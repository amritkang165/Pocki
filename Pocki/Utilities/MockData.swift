import Foundation

/// Sample expenses for previews and first-run demos.
enum MockData {
    static func sampleExpenses(around reference: Date = .now) -> [Expense] {
        let calendar = Calendar.current
        func daysAgo(_ n: Int, hour: Int = 12) -> Date {
            var components = calendar.dateComponents([.year, .month, .day], from: reference)
            let base = calendar.date(from: components) ?? reference
            let day = calendar.date(byAdding: .day, value: -n, to: base) ?? base
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        return [
            Expense(amount: 12.50, merchant: "Blue Bottle", category: .food, date: daysAgo(0, hour: 9), note: "Morning latte"),
            Expense(amount: 48.00, merchant: "Whole Foods", category: .groceries, date: daysAgo(0, hour: 18)),
            Expense(amount: 9.99, merchant: "Spotify", category: .subscriptions, date: daysAgo(1), note: "Monthly plan"),
            Expense(amount: 64.20, merchant: "Uber", category: .travel, date: daysAgo(1, hour: 21)),
            Expense(amount: 120.00, merchant: "Nike", category: .shopping, date: daysAgo(2)),
            Expense(amount: 35.00, merchant: "Cinema City", category: .entertainment, date: daysAgo(3), note: "Weekend movie"),
            Expense(amount: 89.00, merchant: "City Pharmacy", category: .health, date: daysAgo(4)),
            Expense(amount: 42.50, merchant: "Coursera", category: .education, date: daysAgo(5)),
            Expense(amount: 156.00, merchant: "Electric Co.", category: .bills, date: daysAgo(6), note: "July bill"),
            Expense(amount: 28.75, merchant: "Trader Joe's", category: .groceries, date: daysAgo(7)),
            Expense(amount: 15.00, merchant: "Sweetgreen", category: .food, date: daysAgo(8)),
            Expense(amount: 220.00, merchant: "Apple", category: .shopping, date: daysAgo(10), note: "Accessories"),
            Expense(amount: 55.00, merchant: "Shell", category: .travel, date: daysAgo(12)),
            Expense(amount: 18.40, merchant: "Starbucks", category: .food, date: daysAgo(14)),
            Expense(amount: 79.00, merchant: "Netflix", category: .subscriptions, date: daysAgo(15)),
        ]
    }
}
