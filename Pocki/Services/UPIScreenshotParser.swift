import Foundation

/// One OCR text line with its vertical position (0…1, top to bottom).
/// Preserves layout so parsers can use reading order, not just a flat blob.
struct RecognizedLine: Sendable {
    let text: String
    let yPosition: Double
}

/// Best-effort parser for UPI payment screenshot text.
/// Detects the source app first, then applies that app's known layout rules;
/// falls back to generic heuristics when the app can't be identified.
enum UPIScreenshotParser {
    static func parse(_ lines: [RecognizedLine]) -> OCRParseResult {
        let ordered = lines
            .sorted { $0.yPosition < $1.yPosition }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let app = detectApp(from: ordered)
        var result: OCRParseResult

        switch app {
        case .gpay: result = parseGPay(ordered)
        case .phonepe: result = parsePhonePe(ordered)
        case .paytm: result = parsePaytm(ordered)
        case .bhim: result = parseBHIM(ordered)
        case .other: result = parseGeneric(ordered)
        }

        result.sourceApp = app
        return result
    }

    /// Parses a *transaction history* screenshot (a list of payments) into
    /// one result per row. Amounts mark the rows; the merchant is the nearest
    /// plausible name above each amount. One screenshot → many expenses.
    static func parseHistory(_ lines: [RecognizedLine]) -> [OCRParseResult] {
        let ordered = lines
            .sorted { $0.yPosition < $1.yPosition }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !ordered.isEmpty else { return [] }
        let app = detectApp(from: ordered)
        let headerDate = extractHeaderDate(from: ordered) ?? .now

        // 1. Every amount token marks one transaction row.
        let amountIndexes: [Int] = ordered.enumerated().compactMap { index, line in
            extractAmount(from: line) != nil ? index : nil
        }

        guard !amountIndexes.isEmpty else { return [] }

        var transactions: [OCRParseResult] = []
        for (row, amountIndex) in amountIndexes.enumerated() {
            let amount = extractAmount(from: ordered[amountIndex])
            let merchant = historyMerchant(above: ordered, before: amountIndex, skipping: amountIndexes)
            let date = transactionDate(from: ordered, headerDate: headerDate, amountIndex: amountIndex, row: row)

            var score = 0.5
            if amount != nil { score += 0.15 }
            if merchant != nil { score += 0.2 }
            let confidence = min(score, 0.9)

            transactions.append(OCRParseResult(
                amount: amount,
                merchant: merchant,
                date: date,
                confidence: confidence,
                rawText: ordered.joined(separator: "\n"),
                sourceApp: app
            ))
        }
        return transactions
    }

    // MARK: - History helpers

    /// Looks above an amount for the nearest plausible merchant line,
    /// stripping "paid to"/"to:" prefixes and trailing amounts. Never crosses
    /// into the previous transaction's row.
    private static func historyMerchant(above lines: [String], before amountIndex: Int, skipping amountIndexes: [Int]) -> String? {
        for index in stride(from: amountIndex - 1, through: max(0, amountIndex - 5), by: -1) {
            if amountIndexes.contains(index) { return nil }
            if let merchant = historyMerchant(from: lines[index]) {
                return merchant
            }
        }
        return nil
    }

    private static func historyMerchant(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if let keyword = historyKeywords.first(where: { lower.contains($0) }) {
            guard let range = trimmed.range(of: keyword, options: [.caseInsensitive]) else { return nil }
            let after = trimmed[range.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
            let cleaned = cleanMerchant(after)
            if !cleaned.isEmpty, isPlausibleMerchant(cleaned) {
                return cleaned
            }
            return nil
        }
        let cleaned = cleanMerchant(trimmed)
        guard isPlausibleMerchant(cleaned) else { return nil }
        return cleaned
    }

    private static let historyKeywords = ["paid to", "sent to", "to:", "to ", "payment to"]

    /// "Today" / "Yesterday" / a date near the top applies to the whole list.
    private static func extractHeaderDate(from lines: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current

        for line in lines.prefix(4) {
            if let relative = relativeDate(from: line, formatter: formatter) {
                return relative
            }
            for format in ["dd MMM yyyy", "dd/MM/yyyy", "dd-MM-yyyy"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: line) {
                    return date
                }
            }
        }
        return nil
    }

    /// Combines the header day with each row's "· 2:14 PM" time when present.
    private static func transactionDate(from lines: [String], headerDate: Date, amountIndex: Int, row: Int) -> Date {
        let searchRange = lines.indices.contains(amountIndex + 1)
            ? (amountIndex + 1)..<min(lines.count, amountIndex + 3)
            : (amountIndex + 1)..<(amountIndex + 1)

        for index in searchRange {
            let lower = lines[index].lowercased()
            if let time = extractTime(from: lines[index]) {
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: headerDate)
                    ?? headerDate
            }
            if lower.contains("upi") && index + 1 < lines.count,
               let time = extractTime(from: lines[index + 1]) {
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: headerDate)
                    ?? headerDate
            }
        }

        // Keep the row order (roughly 5+ minutes apart) even when no time is visible.
        return Calendar.current.date(byAdding: .minute, value: -row * 5, to: headerDate) ?? headerDate
    }

    // MARK: - App detection

    private static func detectApp(from lines: [String]) -> UPIPaymentApp {
        let text = lines.joined(separator: "\n").lowercased()

        if text.contains("google pay") || text.contains("googlepay") || text.contains("gpay") {
            return .gpay
        }
        if text.contains("phonepe") || text.contains("phone pe") {
            return .phonepe
        }
        if text.contains("paytm") {
            return .paytm
        }
        if text.contains("bhim") || text.contains("vpa") {
            return .bhim
        }
        return .other
    }

    // MARK: - Google Pay

    /// GPay receipt: "You paid ₹250.00 to Chai Point", "UPI transaction ID",
    /// "REFERENCE ID", "Today, 2:14 pm".
    private static func parseGPay(_ lines: [String]) -> OCRParseResult {
        let text = lines.joined(separator: "\n")
        let amount = extractAmount(from: text)
        let merchant = extractMerchantAfterKeywords(in: lines, keywords: ["to", "paid to"])
        let date = extractDate(from: text)

        return score(amount: amount, merchant: merchant, date: date, rawText: text)
    }

    // MARK: - PhonePe

    /// PhonePe receipt: "Payment Successful", "₹250.00", "Paid to", "Chai Point",
    /// "Transaction ID", "Date: 12 Aug, 02:14 PM".
    private static func parsePhonePe(_ lines: [String]) -> OCRParseResult {
        let text = lines.joined(separator: "\n")
        let amount = extractAmount(from: text)
        let merchant = extractMerchantAfterKeywords(in: lines, keywords: ["paid to", "to"])
        let date = extractDate(from: text)

        return score(amount: amount, merchant: merchant, date: date, rawText: text)
    }

    // MARK: - Paytm

    /// Paytm receipt: "Transaction Successful", "₹250.00", "To: Chai Point",
    /// "Date & Time: 12 Aug 2026, 02:14 PM".
    private static func parsePaytm(_ lines: [String]) -> OCRParseResult {
        let text = lines.joined(separator: "\n")
        let amount = extractAmount(from: text)
        let merchant = extractMerchantAfterKeywords(in: lines, keywords: ["to:", "to", "paid to"])
        let date = extractDate(from: text)

        return score(amount: amount, merchant: merchant, date: date, rawText: text)
    }

    // MARK: - BHIM

    /// BHIM receipt: "Transaction Successful", "Amount: Rs. 250.00",
    /// "Paying to", "<name>", "To VPA: …@upi", "Date & Time: 12-08-2026 02:14:56".
    private static func parseBHIM(_ lines: [String]) -> OCRParseResult {
        let text = lines.joined(separator: "\n")
        let amount = extractAmount(from: text)
        let merchant = extractMerchantAfterKeywords(in: lines, keywords: ["paying to", "to:", "to"])
        let date = extractDate(from: text)

        return score(amount: amount, merchant: merchant, date: date, rawText: text)
    }

    // MARK: - Generic fallback

    private static func parseGeneric(_ lines: [String]) -> OCRParseResult {
        let text = lines.joined(separator: "\n")
        let amount = extractAmount(from: text)
        let merchant = extractMerchantAfterKeywords(in: lines, keywords: [
            "paid to", "to:", "to", "payment to", "sent to", "received from", "from:", "merchant", "payee"
        ])
        let date = extractDate(from: text)

        var result = score(amount: amount, merchant: merchant, date: date, rawText: text)
        if result.merchant == nil {
            result.merchant = fallbackMerchant(in: lines)
        }
        return result
    }

    // MARK: - Amount

    private static func extractAmount(from text: String) -> Double? {
        let patterns: [(regex: String, contextual: Bool)] = [
            (#"paid\s+(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, true),
            (#"sent\s+(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, true),
            (#"amount(?:s)?\s*[:\-]?\s*(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, true),
            (#"(?:₹|rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, false),
            (#"([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.[0-9]{1,2})?)"#, false),
            (#"\b([0-9]+\.[0-9]{2})\b"#, false)
        ]

        var contextual: [Double] = []
        var all: [Double] = []
        for (pattern, isContextual) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let swiftRange = Range(match.range(at: 1), in: text) else { return }
                let raw = text[swiftRange].replacingOccurrences(of: ",", with: "")
                if let value = Double(raw), value > 0, value < 10_000_000 {
                    all.append(value)
                    if isContextual { contextual.append(value) }
                }
            }
        }

        let pool = contextual.isEmpty ? all : contextual
        return pool.max()
    }

    // MARK: - Merchant

    /// Finds the merchant that follows a keyword (e.g. "paid to"), either inline
    /// or on the next non-chrome line. Ordered top-to-bottom, so the first hit wins.
    private static func extractMerchantAfterKeywords(in lines: [String], keywords: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard let matchedKeyword = keywords.first(where: { lower.contains($0) }) else { continue }

            if let inline = merchantAfter(line, keyword: matchedKeyword), isPlausibleMerchant(inline) {
                return cleanMerchant(inline)
            }
            // Merchant usually sits on the line right after "Paid to".
            if index + 1 < lines.count {
                let next = lines[index + 1]
                if isPlausibleMerchant(next) {
                    return cleanMerchant(next)
                }
            }
        }
        return nil
    }

    private static func merchantAfter(_ line: String, keyword: String) -> String? {
        guard let range = line.range(of: keyword, options: [.caseInsensitive]) else { return nil }
        let value = line[range.upperBound...]
        return value
            .trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
    }

    private static func fallbackMerchant(in lines: [String]) -> String? {
        for line in lines.prefix(12) {
            if isPlausibleMerchant(line),
               !line.contains("₹"),
               line.count >= 3,
               line.count <= 48 {
                return cleanMerchant(line)
            }
        }
        return nil
    }

    private static func isPlausibleMerchant(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 60 else { return false }

        let lower = trimmed.lowercased()
        if lower.contains("@") || lower.hasPrefix("upi") { return false }
        if lower.contains("upi id") || lower.contains("ref") || lower.contains("transaction") { return false }
        if lower.contains("paid to") || lower.contains("paying to") { return false }
        if lower.contains("successful") || lower.contains("success") { return false }
        if lower.contains("google pay") || lower.contains("phonepe") || lower.contains("paytm") || lower.contains("bhim") { return false }
        if lower.contains("amount") || lower.contains("date") || lower.contains("time") { return false }
        if lower.contains("thank you") || lower.contains("received") || lower.contains("from") { return false }
        if lower.contains("reference") || lower.contains("bank") || lower.contains("accenture") { return false }
        if lower.contains("today") || lower.contains("yesterday") || lower.contains("tomorrow") { return false }
        if trimmed.range(of: #"^\d{1,2}:\d{2}\s*(am|pm)?$"#, options: [.regularExpression, .caseInsensitive]) != nil { return false }
        if trimmed.allSatisfy({ $0.isNumber || $0.isPunctuation }) { return false }
        if trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "₹" }) { return false }
        return true
    }

    private static func cleanMerchant(_ value: String) -> String {
        let stripped = value
            .replacingOccurrences(
                of: #"\s*(?:₹|rs\.?|inr)\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        return stripped
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    // MARK: - Date

    private static func extractDate(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current

        let formats = [
            "dd MMM yyyy, hh:mm:ss a",
            "dd MMM yyyy, h:mm:ss a",
            "dd MMM yyyy, hh:mm a",
            "dd MMM yyyy, h:mm a",
            "dd MMM yyyy hh:mm a",
            "dd MMM yyyy",
            "dd MMM, hh:mm a",
            "dd MMM, h:mm a",
            "dd MMM hh:mm a",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm:ss",
            "dd-MM-yyyy HH:mm",
            "dd-MM-yyyy"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }

        for line in text.components(separatedBy: .newlines) {
            if let relative = relativeDate(from: line, formatter: formatter) {
                return relative
            }
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}(?:,?\s+\d{1,2}:\d{2}(?::\d{2})?\s*[AaPp][Mm])?|\d{1,2}[/-]\d{1,2}[/-]\d{4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)"#
        ) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches {
            guard let swiftRange = Range(match.range(at: 1), in: text) else { continue }
            let snippet = String(text[swiftRange])
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: snippet) {
                    return date
                }
            }
        }
        return nil
    }

    /// Handles GPay-style relative stamps: "Today, 2:14 pm", "Yesterday, 10:30 am".
    private static func relativeDate(from line: String, formatter: DateFormatter) -> Date? {
        let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
        guard lower.hasPrefix("today") || lower.hasPrefix("yesterday") else { return nil }

        let isYesterday = lower.hasPrefix("yesterday")
        guard let time = extractTime(from: line) else {
            return isYesterday ? Calendar.current.date(byAdding: .day, value: -1, to: .now) : .now
        }

        let base = isYesterday
            ? Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            : .now
        return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: base)
    }

    private static func extractTime(from line: String) -> (hour: Int, minute: Int)? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{1,2}):(\d{2})\s*([AaPp][Mm])"#
        ) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges == 4,
              let hourRange = Range(match.range(at: 1), in: line),
              let minuteRange = Range(match.range(at: 2), in: line),
              let meridianRange = Range(match.range(at: 3), in: line),
              let hour = Int(line[hourRange]),
              let minute = Int(line[minuteRange]) else { return nil }

        var h = hour % 12
        if line[meridianRange].lowercased() == "pm" { h += 12 }
        return (h, minute)
    }

    // MARK: - Scoring

    private static func score(amount: Double?, merchant: String?, date: Date?, rawText: String) -> OCRParseResult {
        var score = 0.2
        if amount != nil { score += 0.4 }
        if merchant != nil { score += 0.25 }
        if date != nil { score += 0.15 }

        return OCRParseResult(
            amount: amount,
            merchant: merchant,
            date: date,
            confidence: min(score, 0.97),
            rawText: rawText
        )
    }
}
