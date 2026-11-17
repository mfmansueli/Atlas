//
//  ReviewLanguageDownloadButton.swift
//  Atlas
//

import SwiftUI
import Translation

/// "Download Languages…": asks Apple Translation to download each language
/// the reviews are written in, which shows the system's own prompt, then
/// translates again.
struct ReviewLanguageDownloadButton: View {
    /// "de", "ja".
    let languages: [String]
    let onFinish: () async -> Void

    @State private var downloads = ReviewLanguageDownloads()

    var body: some View {
        let downloads = downloads
        Button("Download Languages…") {
            downloads.start(languages: languages, target: ReviewLanguage.appLanguageCode, onFinish: onFinish)
        }
        .controlSize(.small)
        .disabled(downloads.isRunning)
        .translationTask(downloads.configuration) { @Sendable session in
            try? await session.prepareTranslation()
            await downloads.advance()
        }
        .accessibilityIdentifier("reviews.downloadLanguages")
    }
}
