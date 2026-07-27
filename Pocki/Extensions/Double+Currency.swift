import Foundation

extension Double {
    /// Formats the value as currency using the given ISO currency code.
    func formatted(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = amountHasCents ? 2 : 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Compact currency for charts and tight layouts.
    func compactCurrency(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }

    private var amountHasCents: Bool {
        abs(self.truncatingRemainder(dividingBy: 1)) > 0.001
    }
}
