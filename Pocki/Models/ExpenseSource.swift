import Foundation

/// Origin of an expense entry. Extensible for OCR, imports, and future sources.
enum ExpenseSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case ocr
    case importSource = "import"

    var id: String { rawValue }

    /// User-facing label for the source.
    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .ocr: "Screenshot OCR"
        case .importSource: "Imported"
        }
    }

    /// SF Symbol for the source badge.
    var icon: String {
        switch self {
        case .manual: "hand.tap"
        case .ocr: "text.viewfinder"
        case .importSource: "square.and.arrow.down"
        }
    }
}
