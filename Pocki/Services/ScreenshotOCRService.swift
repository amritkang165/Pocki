import Foundation
import UIKit
import Vision

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
        let text = try await recognizeText(in: image)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return OCRParseResult(
                amount: nil,
                merchant: nil,
                date: nil,
                confidence: 0,
                rawText: ""
            )
        }
        return UPIScreenshotParser.parse(text)
    }

    // MARK: - Vision

    private static func recognizeText(in image: UIImage) async throws -> String {
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
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
