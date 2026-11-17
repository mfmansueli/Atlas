//
//  AppleReviewTranslator.swift
//  Atlas
//

import Foundation
import Translation

/// `ReviewTranslator` backed by Apple's Translation framework, entirely on
/// this Mac: no review text leaves it. Languages have to be downloaded
/// first (System Settings, or Reviews' "Download…").
struct AppleReviewTranslator: ReviewTranslator {
    func availability(from source: String, to target: String) async -> TranslationAvailability {
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
        switch status {
        case .installed: return .ready
        case .supported: return .needsDownload
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        let session = TranslationSession(installedSource: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
        var translated: [String] = []
        for text in texts {
            // An empty title stays empty; Apple Translation refuses it.
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                translated.append(text)
            } else {
                try await translated.append(session.translate(text).targetText)
            }
        }
        return translated
    }
}
