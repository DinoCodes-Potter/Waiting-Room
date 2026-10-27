import CoreGraphics
import Foundation
import Vision

enum Analysis {
    static func recognizeLines(_ image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        return observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 }
    }

    static func summarize(_ lines: [String], mode: TriggerMode) -> String {
        let text = lines.joined(separator: " ").lowercased()
        let failWords = ["error", "failed", "failure", "exception", "fatal", "traceback", "could not", "cannot"]
        let okWords = ["success", "succeeded", "completed", "complete", "done", "passed", "finished", "all tests"]

        var verdict = ""
        if failWords.contains(where: { text.contains($0) }) {
            verdict = "⚠️ Looks like an error."
        } else if okWords.contains(where: { text.contains($0) }) {
            verdict = "✅ Looks successful."
        }

        var tail = lines.suffix(2).joined(separator: " · ")
        if tail.count > 140 { tail = String(tail.prefix(140)) + "…" }

        let head: String
        switch mode {
        case .stops: head = "Stopped changing."
        case .starts: head = "Something started changing."
        case .every: head = "The screen changed."
        }
        return [head, verdict, tail].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
