//
//  FakeReviewTranslator.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Translates by tagging the text ("[de→en] Titel"), with languages that
/// need a download or can't be translated.
struct FakeReviewTranslator: ReviewTranslator {
    var needsDownload: Set<String> = []
    var unsupported: Set<String> = []

    func availability(from source: String, to _: String) async -> TranslationAvailability {
        if unsupported.contains(source) { return .unsupported }
        return needsDownload.contains(source) ? .needsDownload : .ready
    }

    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        texts.map { "[\(source)→\(target)] \($0)" }
    }
}
