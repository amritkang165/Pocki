import Foundation

/// One OCR text line with its position (0…1). y is top-to-bottom, x is
/// left-to-right, so parsers can reconstruct rows and columns.
struct RecognizedLine: Sendable {
    let text: String
    let yPosition: Double
    let xPosition: Double
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
        let year = extractYear(from: lines)

        struct AmountHit {
            let value: Double
            let hasSymbol: Bool
            let y: Double
            let x: Double
            let text: String
        }

        // 1. Every amount token marks one transaction row. Handles ₹/R/$/Rs/INR
        // (OCR often reads ₹ as R or $, or drops it) and bare trailing numbers.
        // Lines in the status bar (top ~6%) are never amounts.
        let hits: [AmountHit] = lines.compactMap { line in
            guard line.yPosition > 0.06 else { return nil }
            guard let (value, hasSymbol) = extractRowAmount(from: line.text) else { return nil }
            return AmountHit(value: value, hasSymbol: hasSymbol, y: line.yPosition, x: line.xPosition, text: line.text)
        }
        guard !hits.isEmpty else { return [] }

        var transactions: [OCRParseResult] = []
        var row = 0

        for hit in hits {
            // 2. Merchant: same line to the left (column layout) → inline in one
            //    observation → nearest plausible line above (stacked layout).
            let merchant = sameRowMerchant(for: (y: hit.y, x: hit.x), lines: lines)
                ?? inlineMerchant(in: hit.text)
                ?? (hit.hasSymbol ? aboveMerchant(for: hit.y, lines: lines) : nil)

            if isStatementChrome(merchant) { continue }
            if isFailedNear(hit.y, lines: lines) { continue }
            // Bare numbers without any merchant are ambiguous chrome, not rows.
            if !hit.hasSymbol && merchant == nil { continue }

            let date = nearestDate(for: hit.y, lines: lines, year: year, headerDate: headerDate, row: row)
            row += 1

            var score = 0.5
            score += 0.15
            if merchant != nil { score += 0.2 }
            if date != headerDate { score += 0.05 }
            let confidence = min(score, 0.9)

            transactions.append(OCRParseResult(
                amount: hit.value,
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

    /// Extracts a row amount, tolerating how OCR mangles ₹:
    /// "R75", "$131", "₹250.00", "Rs. 250", "INR 5000" or bare "790" / "7334".
    private static func extractRowAmount(from text: String) -> (value: Double, hasSymbol: Bool)? {
        // 1. Symbol-prefixed. "R" only counts when directly before a digit
        //    (so "Received" never matches).
        let symbolPattern = #"(?:₹|\$|rs\.?|inr|\bR(?=[0-9]))\s*([0-9][0-9, ]*(?:\.[0-9]{1,2})?)"#
        if let match = firstMatch(symbolPattern, in: text, group: 1),
           let value = moneyValue(of: match) {
            return (value, true)
        }

        // 2. Bare trailing number (column layouts print amounts without any symbol).
        let barePattern = #"([0-9]{2,9}(?:[ ,][0-9]{2,3}){0,2}(?:\.[0-9]{1,2})?)\s*$"#
        if let match = firstMatch(barePattern, in: text, group: 1),
           let value = moneyValue(of: match) {
            return (value, false)
        }
        return nil
    }

    /// Normalizes an OCR money token into a Double.
    /// "48,944.90" → 48944.9 · "346 805 90" (spaced) → 346805.9 · "7334" → 7334.
    private static func moneyValue(of raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(".") {
            return Double(trimmed.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: ""))
        }

        let groups = trimmed.components(separatedBy: " ")
        if groups.count > 1, let last = groups.last, last.count == 2,
           let integer = Double(groups.dropLast().joined()),
           let cents = Double(last) {
            return integer + cents / 100
        }

        let compact = trimmed.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        guard let value = Double(compact), value > 0, value < 10_000_000 else { return nil }
        return value
    }

    private static func firstMatch(_ pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > group,
              let swiftRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[swiftRange])
    }

    /// Column layout: merchant and amount are separate observations on the same
    /// visual line, merchant to the left ("SWIGGY INSTAMART" + "$131").
    private static func sameRowMerchant(for hit: (y: Double, x: Double), lines: [RecognizedLine]) -> String? {
        var best: (merchant: String, dy: Double)?
        for line in lines {
            guard line.xPosition < hit.x - 0.001 else { continue }
            let dy = abs(line.yPosition - hit.y)
            guard dy < 0.012, let merchant = historyMerchant(from: line.text) else { continue }
            if best == nil || dy < best!.dy {
                best = (merchant, dy)
            }
        }
        return best?.merchant
    }

    /// Merchant and amount in one observation: "You paid Metro Card ₹120.00".
    private static func inlineMerchant(in text: String) -> String? {
        let pattern = #"(?:₹|\$|rs\.?|inr|\bR(?=[0-9])|[0-9])\s*[0-9][0-9, .]*[0-9]\s*$"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let before = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        guard !before.isEmpty else { return nil }
        return historyMerchant(from: before)
    }

    /// Stacked layout: amount on its own line, merchant on the line above.
    private static func aboveMerchant(for y: Double, lines: [RecognizedLine]) -> String? {
        var best: (merchant: String, dy: Double)?
        for line in lines {
            let dy = y - line.yPosition
            guard dy > 0.012, dy <= 0.15, let merchant = historyMerchant(from: line.text) else { continue }
            if best == nil || dy < best!.dy {
                best = (merchant, dy)
            }
        }
        return best?.merchant
    }

    /// Rows like "You spent ₹15,000 in July" or "Total spent" are statement
    /// chrome, not transactions — skip them.
    private static func isStatementChrome(_ merchant: String?) -> Bool {
        guard let merchant else { return false }
        let lower = merchant.lowercased()
        let months = ["january", "february", "march", "april", "may", "june", "july",
                      "august", "september", "october", "november", "december"]
        let skipWords = ["total", "spent", "balance", "available", "limit", "statement",
                         "summary", "month", "account", "payment method", "date", "status"] + months
        return skipWords.contains { lower.contains($0) }
    }

    /// Failed rows carry a status like "Failed" just below the amount.
    private static func isFailedNear(_ y: Double, lines: [RecognizedLine]) -> Bool {
        let failedWords = ["failed", "cancelled", "canceled", "reversed", "unsuccessful", "declined", "refunded"]
        return lines.contains { line in
            let dy = line.yPosition - y
            guard dy >= -0.03, dy <= 0.10 else { return false }
            let lower = line.text.lowercased()
            return failedWords.contains { lower.contains($0) }
        }
    }

    /// Date for a row: the nearest "29 July" line (±0.12 in y) combined with the
    /// header year; falls back to the header date when no row date exists.
    private static func nearestDate(for y: Double, lines: [RecognizedLine], year: Int?, headerDate: Date, row: Int) -> Date {
        var best: (date: Date, dy: Double)?
        for line in lines {
            let dy = abs(line.yPosition - y)
            guard dy <= 0.12, let date = dayMonthDate(from: line.text, year: year) else { continue }
            if best == nil || dy < best!.dy {
                best = (date, dy)
            }
        }
        if let best { return best.date }

        // Stacked layouts: header day + nearest time on lines below.
        var bestTime: (hour: Int, minute: Int)?
        var bestTimeDy = Double.greatestFiniteMagnitude
        for line in lines {
            let dy = line.yPosition - y
            guard dy > 0.005, dy <= 0.10, let time = extractTime(from: line.text) else { continue }
            if dy < bestTimeDy {
                bestTime = time
                bestTimeDy = dy
            }
        }
        if let bestTime {
            return Calendar.current.date(bySettingHour: bestTime.hour, minute: bestTime.minute, second: 0, of: headerDate)
                ?? headerDate
        }
        return Calendar.current.date(byAdding: .minute, value: -row * 5, to: headerDate) ?? headerDate
    }

    /// "29 July" (optionally with a year) → Date, using the header year if missing.
    private static func dayMonthDate(from text: String, year: Int?) -> Date? {
        let pattern = #"\b(\d{1,2})\s+([A-Za-z]{3,})(?:\s+(\d{4}))?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges == 4,
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let day = Int(text[dayRange]),
              let month = monthNumber(String(text[monthRange])) else { return nil }

        var yearValue = year
        if match.range(at: 3).location != NSNotFound,
           let yRange = Range(match.range(at: 3), in: text) {
            yearValue = Int(text[yRange])
        }
        guard let yearValue else { return nil }

        var components = DateComponents()
        components.year = yearValue
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)
    }

    private static func monthNumber(_ name: String) -> Int? {
        let lower = name.lowercased()
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        for (index, prefix) in months.enumerated() where lower.hasPrefix(prefix) {
            return index + 1
        }
        return nil
    }

    /// A "2026" year label near the top of a statement.
    private static func extractYear(from lines: [RecognizedLine]) -> Int? {
        for line in lines where line.yPosition < 0.3 {
            let pattern = #"\b(20\d{2})\b"#
            if let range = line.text.range(of: pattern, options: .regularExpression),
               let value = Int(line.text[range]) {
                return value
            }
        }
        return nil
    }

    private static func historyMerchant(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // "You paid Chai Point" / "Paid to Zomato" / "To: Jio" → strip the verb.
        let stripped = trimmed.replacingOccurrences(
            of: #"^(you\s+)?(paid|sent|pay|recharged|spent)\s*(to\s+)?(via\s+)?"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).replacingOccurrences(
            of: #"^to\s*:?\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        let cleanedStripped = cleanMerchant(stripped)
        if !cleanedStripped.isEmpty, isPlausibleMerchant(cleanedStripped) {
            return cleanedStripped
        }

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
