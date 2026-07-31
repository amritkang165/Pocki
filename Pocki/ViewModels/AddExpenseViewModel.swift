import Foundation
import Observation
import UIKit

/// Form state and validation for creating or editing an expense.
@MainActor
@Observable
final class AddExpenseViewModel {
    var amountText: String = ""
    var merchant: String = ""
    var category: ExpenseCategory = .food
    var date: Date = .now
    var note: String = ""

    /// Set when the entry came from a UPI screenshot.
    var source: ExpenseSource = .manual
    var confidence: Double?
    var isVerified: Bool = true

    var screenshotImage: UIImage?
    var isScanningScreenshot: Bool = false
    var screenshotStatusMessage: String?
    var screenshotErrorMessage: String?

    var editingExpense: Expense?

    private let expenseService: ExpenseService

    init(expenseService: ExpenseService, editingExpense: Expense? = nil) {
        self.expenseService = expenseService
        self.editingExpense = editingExpense
        if let editingExpense {
            load(from: editingExpense)
        }
    }

    var isEditing: Bool { editingExpense != nil }

    var parsedAmount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var isValid: Bool {
        parsedAmount != nil && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var title: String { isEditing ? "Edit Expense" : "Add Expense" }
    var saveTitle: String { isEditing ? "Save Changes" : "Save Expense" }

    var showsScreenshotImport: Bool { !isEditing }

    func load(from expense: Expense) {
        amountText = expense.amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(expense.amount))
            : String(format: "%.2f", expense.amount)
        merchant = expense.merchant
        category = expense.category
        date = expense.date
        note = expense.note ?? ""
        source = expense.source
        confidence = expense.confidence
        isVerified = expense.isVerified
    }

    /// Runs on-device OCR and prefills fields. User still confirms before save.
    func importScreenshot(_ image: UIImage) async {
        screenshotImage = image
        screenshotErrorMessage = nil
        screenshotStatusMessage = "Reading UPI screenshot…"
        isScanningScreenshot = true

        do {
            let result = try await ScreenshotOCRService.parseExpense(from: image)
            apply(parseResult: result)
            if result.didExtractAnything {
                screenshotStatusMessage = "Review the fields below, then save."
                HapticService.success()
            } else {
                screenshotStatusMessage = "Couldn’t find payment details — fill them in manually."
                HapticService.warning()
            }
        } catch {
            screenshotErrorMessage = error.localizedDescription
            screenshotStatusMessage = nil
            source = .manual
            HapticService.error()
        }

        isScanningScreenshot = false
    }

    func clearScreenshot() {
        screenshotImage = nil
        screenshotStatusMessage = nil
        screenshotErrorMessage = nil
        confidence = nil
        if !isEditing {
            source = .manual
            isVerified = true
        }
    }

    func apply(parseResult: OCRParseResult) {
        source = .ocr
        confidence = parseResult.confidence
        isVerified = false

        if let amount = parseResult.amount {
            amountText = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(format: "%.2f", amount)
        }
        if let merchant = parseResult.merchant, !merchant.isEmpty {
            self.merchant = merchant
        }
        if let date = parseResult.date {
            self.date = date
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let amount = parsedAmount else { return false }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty else { return false }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSource = source
        let resolvedConfidence = source == .ocr ? confidence : nil
        // Saving after review counts as verification for OCR entries.
        let resolvedVerified = source == .ocr ? true : isVerified

        if let editingExpense {
            editingExpense.amount = amount
            editingExpense.merchant = trimmedMerchant
            editingExpense.category = category
            editingExpense.date = date
            editingExpense.note = trimmedNote.isEmpty ? nil : trimmedNote
            editingExpense.source = resolvedSource
            editingExpense.confidence = resolvedConfidence
            editingExpense.isVerified = resolvedVerified
            expenseService.update(editingExpense)
        } else {
            let expense = Expense(
                amount: amount,
                merchant: trimmedMerchant,
                category: category,
                date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                source: resolvedSource,
                isVerified: resolvedVerified,
                confidence: resolvedConfidence
            )
            expenseService.create(expense)
        }

        HapticService.success()
        return true
    }
}
