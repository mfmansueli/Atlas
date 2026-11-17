//
//  ReviewLanguageDownloads.swift
//  Atlas
//

import Foundation
import Observation
import Translation

/// The languages Reviews still has to ask Apple Translation for, one at a
/// time: each becomes a `TranslationSession.Configuration` that
/// `.translationTask` turns into the system's download prompt.
@MainActor
@Observable
final class ReviewLanguageDownloads {
    private(set) var configuration: TranslationSession.Configuration?
    private var remaining: [String] = []
    private var target = "en"
    private var onFinish: (() async -> Void)?

    var isRunning: Bool { configuration != nil }

    func start(languages: [String], target: String, onFinish: @escaping () async -> Void) {
        remaining = languages
        self.target = target
        self.onFinish = onFinish
        advance()
    }

    /// The current language is done (downloaded or declined): ask for the
    /// next, or report back when there's none left.
    func advance() {
        guard !remaining.isEmpty else {
            configuration = nil
            let onFinish = onFinish
            self.onFinish = nil
            Task { await onFinish?() }
            return
        }
        let source = remaining.removeFirst()
        configuration = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
    }
}
