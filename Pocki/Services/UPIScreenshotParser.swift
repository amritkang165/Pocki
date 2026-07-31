import Foundation

/// Best-effort parser for UPI payment screenshot text (any UPI app).
enum UPIScreenshotParser {
    /// Parses OCR text into amount, merchant, and date when possible.
    static func parse(_ text: String) -> OCRParseResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let amount = extractAmount(from: text, lines: lines)
        let merchant = extractMerchant(from: lines)
        let date = extractDate(from: text, lines: lines)

        var score = 0.15
        if amount != nil { score += 0.45 }
        if merchant != nil { score += 0.25 }
        if date != nil { score += 0.15 }

        return OCRParseResult(
            amount: amount,
            merchant: merchant,
            date: date,
            confidence: min(score, 0.95),
            rawText: text
        )
    }

    // MARK: - Amount

    private static func extractAmount(from text: String, lines: [String]) -> Double? {
        let patterns = [
            #"₹\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)"#,
            #"(?:Rs\.?|INR|₹)\s*([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)"#,
            #"([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.[0-9]{1,2})?)"#,
            #"\b([0-9]+\.[0-9]{2})\b"#
        ]

        var candidates: [Double] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match,
                      match.numberOfRanges > 1,
                      let swiftRange = Range(match.range(at: 1), in: text) else { return }
                let raw = text[swiftRange]
                    .replacingOccurrences(of: ",", with: "")
                if let value = Double(raw), value > 0, value < 10_000_000 {
                    candidates.append(value)
                }
            }
        }

        // Prefer amounts mentioned near payment keywords.
        let lowered = text.lowercased()
        if lowered.contains("paid") || lowered.contains("payment") || lowered.contains("sent") {
            return candidates.max()
        }
        return candidates.max()
    }

    // MARK: - Merchant

    private static func extractMerchant(from lines: [String]) -> String? {
        let prefixes = [
            "paid to", "to:", "to ", "payment to", "sent to",
            "received from", "from:", "merchant", "payee"
        ]
        let skipExact = Set([
            "payment successful", "paid successfully", "successful",
            "google pay", "phonepe", "paytm", "bhim", "amazon pay",
            "upi", "transaction successful", "money sent"
        ])

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            for prefix in prefixes where lower.hasPrefix(prefix) || lower.contains(prefix) {
                var value = line
                for p in prefixes {
                    if let range = value.range(of: p, options: [.caseInsensitive, .anchored]) {
                        value = String(value[range.upperBound...])
                        break
                    }
                    if let range = value.range(of: p, options: .caseInsensitive) {
                        value = String(value[range.upperBound...])
                        break
                    }
                }
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
                if isPlausibleMerchant(value, skipExact: skipExact) {
                    return cleanMerchant(value)
                }
                // Often merchant is the next line after "Paid to"
                if index + 1 < lines.count {
                    let next = lines[index + 1]
                    if isPlausibleMerchant(next, skipExact: skipExact) {
                        return cleanMerchant(next)
                    }
                }
            }
        }

        // Fallback: first plausible title-ish line that isn't pure numbers / UPI chrome.
        for line in lines.prefix(12) {
            if isPlausibleMerchant(line, skipExact: skipExact),
               !line.contains("₹"),
               line.count >= 3,
               line.count <= 48 {
                return cleanMerchant(line)
            }
        }
        return nil
    }

    private static func isPlausibleMerchant(_ value: String, skipExact: Set<String>) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 60 else { return false }
        let lower = trimmed.lowercased()
        if skipExact.contains(lower) { return false }
        if trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "₹" }) { return false }
        if lower.contains("upi id") || lower.contains("@oksbi") || lower.contains("@paytm") { return false }
        if lower.hasPrefix("txn") || lower.hasPrefix("utr") { return false }
        return true
    }

    private static func cleanMerchant(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    // MARK: - Date

    private static func extractDate(from text: String, lines: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current

        let formats = [
            "dd MMM yyyy, hh:mm a",
            "dd MMM yyyy, h:mm a",
            "dd MMM yyyy hh:mm a",
            "dd MMM yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm",
            "dd-MM-yyyy"
        ]

        for line in lines {
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: line) {
                    return date
                }
            }
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}(?:,?\s+\d{1,2}:\d{2}\s*[AaPp][Mm])?)"#
        ) else {
            return nil
        }

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
}