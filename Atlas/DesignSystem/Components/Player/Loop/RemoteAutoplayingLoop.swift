//
//  RemoteAutoplayingLoop.swift
//  Atlas
//

import SwiftUI

/// `AutoplayingLoop` for a movie on the internet (an In-App Event's clip
/// that App Store Connect streams): the still until `RemoteVideoCache` has
/// the movie on this Mac, then the loop over it, muted on repeat. It
/// downloads only when moving artwork plays, so a person who keeps it
/// still downloads nothing; one downloaded before plays from the first
/// frame.
struct RemoteAutoplayingLoop<Still: View>: View {
    /// The movie's address (or a file on this Mac); nil shows the still.
    let url: URL?
    var fills = true
    var cache = RemoteVideoCache.shared
    @ViewBuilder let still: (_ isPlaying: Bool) -> Still

    /// Nil outside the app's windows (previews): plays.
    @Environment(AppPreferences.self) private var preferences: AppPreferences?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loaded: Loaded?

    var body: some View {
        let plays = url != nil && AutoplayingLoop<EmptyView>.plays(setting: preferences?.autoplaysMotion ?? true, reduceMotion: reduceMotion)
        AutoplayingLoop(url: plays ? file : nil, fills: fills, still: still)
            .task(id: plays ? url : nil) {
                guard plays, let url, file == nil else { return }
                let found = try? await cache.file(for: url)
                guard !Task.isCancelled, let found else { return }
                loaded = Loaded(source: url, file: found)
            }
    }

    /// The movie on this Mac for `url`: found by the task, else one this
    /// launch already has.
    private var file: URL? {
        guard let url else { return nil }
        if let loaded, loaded.source == url { return loaded.file }
        return cache.cachedFile(for: url)
    }

    /// A movie on this Mac and the address it came from.
    private struct Loaded: Equatable {
        let source: URL
        let file: URL
    }
}
