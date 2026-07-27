import Foundation

/// Placeholder for future CSV / PDF export.
enum ExportService {
    /// Reserved for future CSV export of expenses.
    static func exportCSV(expenses: [Expense]) -> String? {
        // Future: generate CSV for share sheet.
        _ = expenses
        return nil
    }

    /// Reserved for future PDF statement export.
    static func exportPDF(expenses: [Expense]) -> Data? {
        _ = expenses
        return nil
    }
}
