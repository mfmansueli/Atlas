//
//  DebugReviewTranslator.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Apple Translation for DEBUG scenes: every language is ready (or the
/// ones in `needsDownload` aren't), and a text reads back marked as
/// translated. The sample reviews come with their translations, so this
/// only answers for text typed or loaded later.
struct DebugReviewTranslator: ReviewTranslator {
    var needsDownload: Set<String> = []

    func availability(from source: String, to _: String) async -> TranslationAvailability {
        needsDownload.contains(source) ? .needsDownload : .ready
    }

    func translate(_ texts: [String], from source: String, to _: String) async throws -> [String] {
        texts.map { $0.isEmpty ? $0 : "\($0) (from \(source))" }
    }
}
#endif
