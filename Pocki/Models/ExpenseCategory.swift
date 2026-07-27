import Foundation
import SwiftUI

/// Predefined expense categories for Pocki.
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case food = "Food"
    case shopping = "Shopping"
    case travel = "Travel"
    case bills = "Bills"
    case entertainment = "Entertainment"
    case health = "Health"
    case education = "Education"
    case groceries = "Groceries"
    case subscriptions = "Subscriptions"
    case other = "Other"

    var id: String { rawValue }

    /// SF Symbol representing this category.
    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .shopping: "bag"
        case .travel: "airplane"
        case .bills: "doc.text"
        case .entertainment: "film"
        case .health: "heart"
        case .education: "book"
        case .groceries: "cart"
        case .subscriptions: "repeat"
        case .other: "ellipsis.circle"
        }
    }

    /// Accent color for badges and charts.
    var color: Color {
        switch self {
        case .food: Color(red: 0.95, green: 0.45, blue: 0.35)
        case .shopping: Color(red: 0.35, green: 0.55, blue: 0.95)
        case .travel: Color(red: 0.25, green: 0.75, blue: 0.85)
        case .bills: Color(red: 0.55, green: 0.45, blue: 0.85)
        case .entertainment: Color(red: 0.95, green: 0.55, blue: 0.25)
        case .health: Color(red: 0.95, green: 0.35, blue: 0.45)
        case .education: Color(red: 0.30, green: 0.65, blue: 0.55)
        case .groceries: Color(red: 0.40, green: 0.75, blue: 0.40)
        case .subscriptions: Color(red: 0.60, green: 0.50, blue: 0.90)
        case .other: Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }
}
