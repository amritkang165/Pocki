import Foundation
import Observation
import UIKit

/// One editable row detected from a transaction-history screenshot.
@MainActor
@Observable
final class HistoryTransaction: Identifiable {
    let id = UUID()
    var amountText: String
    var merchant: String
    var date: Date
    var isIncluded: Bool
    let isFailed: Bool
    let confidence: Double

    var amount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    init(result: OCRParseResult, defaultDate: Date) {
        if let amount = result.amount {
            amountText = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(format: "%.2f", amount)
        } else {
            amountText = ""
        }
        merchant = result.merchant ?? ""
        date = result.date ?? defaultDate
        isFailed = result.isFailed
        isIncluded = !result.isFailed
        confidence = result.confidence
    }
}

/// State for importing a whole UPI transaction-history screenshot as
/// multiple expenses. Every row is reviewed before anything is saved.
@MainActor
@Observable
final class HistoryImportViewModel {
    private(set) var transactions: [HistoryTransaction] = []
    private(set) var sourceApp: UPIPaymentApp?
    private(set) var screenshotImage: UIImage?
    private(set) var isScanning: Bool = false
    var statusMessage: String?
    var errorMessage: String?

    private let expenseService: ExpenseService

    init(expenseService: ExpenseService) {
        self.expenseService = expenseService
    }

    var includedTransactions: [HistoryTransaction] {
        transactions.filter(\.isIncluded)
    }

    var failedTransactions: [HistoryTransaction] {
        transactions.filter(\.isFailed)
    }

    var includedTotal: Double {
        includedTransactions.compactMap(\.amount).reduce(0, +)
    }

    var isValid: Bool {
        !includedTransactions.isEmpty
            && includedTransactions.allSatisfy { $0.amount != nil && !$0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Runs on-device OCR across the screenshot and builds editable rows.
    func importHistory(_ image: UIImage) async {
        screenshotImage = image
        errorMessage = nil
        statusMessage = "Reading transaction history…"
        isScanning = true

        do {
            let results = try await ScreenshotOCRService.parseHistory(from: image)
            sourceApp = results.first?.sourceApp
            transactions = results.map { HistoryTransaction(result: $0, defaultDate: .now) }

            if transactions.isEmpty {
                statusMessage = "Couldn’t find any transactions — try the receipt screenshot instead."
                HapticService.warning()
            } else {
                let failed = failedTransactions.count
                statusMessage = "\(transactions.count) transaction\(transactions.count == 1 ? "" : "s") found\(failed == 0 ? "" : " · \(failed) failed") — review each row."
                HapticService.success()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            HapticService.error()
        }

        isScanning = false
    }

    func clear() {
        screenshotImage = nil
        transactions = []
        sourceApp = nil
        statusMessage = nil
        errorMessage = nil
    }

    func remove(_ transaction: HistoryTransaction) {
        transactions.removeAll { $0 === transaction }
    }

    /// Saves every included row as its own expense. Saving after review
    /// counts as verification for OCR entries.
    @discardableResult
    func saveAll() -> Bool {
        let rows = includedTransactions
        guard !rows.isEmpty else { return false }

        for row in rows {
            guard let amount = row.amount else { continue }
            let merchant = row.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }

            let expense = Expense(
                amount: amount,
                merchant: merchant,
                category: .other,
                date: row.date,
                source: .ocr,
                isVerified: true,
                confidence: row.confidence
            )
            expenseService.create(expense)
        }

        HapticService.success()
        return true
    }
}
