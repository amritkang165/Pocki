import Foundation

/// Structured fields extracted from a UPI payment screenshot.
struct OCRParseResult: Sendable {
    var amount: Double?
    var merchant: String?
    var date: Date?
    /// Overall confidence from 0…1 for the best-effort parse.
    var confidence: Double
    /// Raw OCR text for debugging / future parsers.
    var rawText: String

    var didExtractAnything: Bool {
        amount != nil || !(merchant?.isEmpty ?? true) || date != nil
    }
}
