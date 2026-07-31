import Foundation
import UIKit
import Vision

/// One OCR pass, parsed two ways so callers can route a screenshot to the
/// right flow (single receipt vs. history list) without re-scanning.
struct ScreenshotScan: Sendable {
    var single: OCRParseResult
    var history: [OCRParseResult]
}

/// On-device OCR for UPI payment screenshots.
enum ScreenshotOCRService {
    enum OCRError: LocalizedError {
        case invalidImage
        case recognitionFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage: "Could not read that image."
            case .recognitionFailed: "Text recognition failed. Try another screenshot."
            }
        }
    }

    /// Runs Vision text recognition, then parses UPI-style fields.
    static func parseExpense(from image: UIImage) async throws -> OCRParseResult {
        let lines = try await recognizeLines(in: image)
        guard !lines.isEmpty else {
            return OCRParseResult(
                amount: nil,
                merchant: nil,
                date: nil,
                confidence: 0,
                rawText: ""
            )
        }
        return UPIScreenshotParser.parse(lines)
    }

    /// Runs Vision text recognition on a transaction *history* screenshot and
    /// returns one parsed result per payment row. Each row's amount is
    /// cross-checked with a second OCR pass on an upscaled image.
    static func parseHistory(from image: UIImage) async throws -> [OCRParseResult] {
        let lines = try await recognizeLines(in: image)
        return try await recognizeHistory(initialLines: lines, in: image)
    }

    /// Runs one OCR pass and returns both the single-receipt and history parses.
    /// If `history.count >= 2` the screenshot is a transaction list, not a receipt.
    static func scan(from image: UIImage) async throws -> ScreenshotScan {
        let lines = try await recognizeLines(in: image)
        return ScreenshotScan(
            single: UPIScreenshotParser.parse(lines),
            history: try await recognizeHistory(initialLines: lines, in: image)
        )
    }

    // MARK: - Dual-pass amount check

    /// Parses history rows from a first OCR pass, then re-reads the same image
    /// upscaled. Rows whose amount disagrees between the two reads are flagged
    /// (`needsReview`) so the user can verify them before saving.
    private static func recognizeHistory(initialLines: [RecognizedLine], in image: UIImage) async throws -> [OCRParseResult] {
        let first = UPIScreenshotParser.parseHistory(initialLines)
        guard let upscaled = image.upscaledImageBy2() else { return first }
        let lines = try await recognizeLines(in: upscaled)
        let second = UPIScreenshotParser.parseHistory(lines)

        var merged = first
        guard first.count == second.count else {
            for i in merged.indices { merged[i].needsReview = true }
            return merged
        }
        for i in merged.indices {
            guard let firstAmount = first[i].amount, let secondAmount = second[i].amount else { continue }
            if abs(firstAmount - secondAmount) > 0.005 {
                merged[i].needsReview = true
                merged[i].altAmount = secondAmount
            }
        }
        return merged
    }

    // MARK: - Vision

    /// Recognizes text lines with their vertical position, top to bottom,
    /// so the parser can follow each UPI app's layout.
    private static func recognizeLines(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { observation -> RecognizedLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    // Vision's boundingBox is normalized with origin at bottom-left.
                    let yFromTop = 1.0 - Double(observation.boundingBox.midY)
                    let xFromLeft = Double(observation.boundingBox.midX)
                    return RecognizedLine(
                        text: candidate.string,
                        yPosition: yFromTop,
                        xPosition: xFromLeft
                    )
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-IN", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension UIImage {
    /// Returns a copy with double the pixel dimensions, used for a second,
    /// sharper OCR pass so symbol-plus-digit reads can be cross-checked.
    func upscaledImageBy2() -> UIImage? {
        let size = CGSize(width: self.size.width * 2, height: self.size.height * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
