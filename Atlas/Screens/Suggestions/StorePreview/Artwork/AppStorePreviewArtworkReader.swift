//
//  AppStorePreviewArtworkReader.swift
//  Atlas
//

import SwiftUI

/// Reads a language's header and search artwork for the App Store preview
/// (what's live through `LiveArtworkMemo`, what waits from the screenshot
/// document, screenshots 1–3 through `LiveShotsMemo`) and hands it to
/// the preview it wraps. Seen before in this launch, the first frame has it.
struct AppStorePreviewArtworkReader<Content: View>: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    let localizations: [StoreLocale: String]
    let locale: StoreLocale
    let primary: StoreLocale
    var artworkMemo: LiveArtworkMemo = .shared
    var shotsMemo: LiveShotsMemo = .shared
    /// The document a Screenshots page holds, so its changes show at once.
    var knownDocument: ScreenshotsDocument?
    @ViewBuilder let content: (AppStorePreviewArtwork) -> Content

    @State private var live: LiveStoreArtworkSet?
    @State private var shots: LiveScreenshots?
    /// The document read here, when no Screenshots view keeps it in step.
    @State private var readDocument: ScreenshotsDocument?

    var body: some View {
        content(artwork)
            .task(id: key) { await read() }
    }

    private var key: LiveShotsMemo.Key {
        LiveShotsMemo.Key(appID: app.id, localizations: localizations)
    }

    private var document: ScreenshotsDocument? {
        knownDocument ?? services.documentCenter?.documents[app.id] ?? readDocument
    }

    private var artwork: AppStorePreviewArtwork {
        let keptShots = shots ?? shotsMemo.kept(key)
        return AppStorePreviewArtwork(
            locale: locale.code, live: live ?? artworkMemo.kept(key) ?? LiveStoreArtworkSet(), extras: document?.extras,
            searchShots: keptShots.map { AppStorePreviewArtwork.searchShots(in: $0, locale: locale, primary: primary) } ?? []
        )
    }

    private func read() async {
        let key = key
        if artworkMemo.needsRead(key) {
            let read = await artworkMemo.read(key) { [services, app, localizations] in
                try await services.liveArtwork(for: app, localizations: localizations)
            }
            guard !Task.isCancelled else { return }
            if read != live { live = read }
        } else if live != artworkMemo.kept(key) {
            live = artworkMemo.kept(key)
        }
        if shotsMemo.needsRead(key) {
            let read = await shotsMemo.read(key) { [services, app, localizations] in
                try await services.liveScreenshots(for: app, localizations: localizations)
            }
            guard !Task.isCancelled else { return }
            if read != shots { shots = read }
        }
        if knownDocument == nil, services.documentCenter?.documents[app.id] == nil, readDocument == nil {
            readDocument = try? await services.document(for: app, primaryLocale: primary)
        }
    }
}
