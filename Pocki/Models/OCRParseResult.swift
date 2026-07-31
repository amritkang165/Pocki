import Foundation

/// The UPI app a payment screenshot came from.
enum UPIPaymentApp: String, CaseIterable, Sendable {
    case gpay
    case phonepe
    case paytm
    case bhim
    case other

    var displayName: String {
        switch self {
        case .gpay: "Google Pay"
        case .phonepe: "PhonePe"
        case .paytm: "Paytm"
        case .bhim: "BHIM UPI"
        case .other: "UPI"
        }
    }
}

/// Structured fields extracted from a UPI payment screenshot.
struct OCRParseResult: Sendable {
    var amount: Double?
    var merchant: String?
    var date: Date?
    /// Overall confidence from 0…1 for the best-effort parse.
    var confidence: Double
    /// Raw OCR text for debugging / future parsers.
    var rawText: String
    /// Which UPI app the screenshot belongs to, if detected.
    var sourceApp: UPIPaymentApp = .other
    /// True for history rows the bank marked "Failed" / "Cancelled" / "Reversed".
    var isFailed: Bool = false
    /// True when a second OCR pass read this row's amount differently, so the
    /// amount is likely misread and deserves a human look.
    var needsReview: Bool = false
    /// The amount the second OCR pass read, when it disagrees with the first.
    var altAmount: Double? = nil

    var didExtractAnything: Bool {
        amount != nil || !(merchant?.isEmpty ?? true) || date != nil
    }
}
