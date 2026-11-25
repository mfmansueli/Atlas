//
//  AutoplayingLoop.swift
//  Atlas
//

import SwiftUI

/// A moving artwork's still with its loop playing over it, muted and on
/// repeat, when the person lets moving artwork play (Settings → General →
/// "Play moving artwork") and Reduce Motion is off. Otherwise the still
/// alone. `still` is told whether the loop plays, to hide a play mark.
/// Scrolled out of view, the movie is let go (the still stays), so a long
/// gallery doesn't decode loops nobody sees.
struct AutoplayingLoop<Still: View>: View {
    /// The movie file on this Mac; nil shows the still.
    let url: URL?
    var fills = true
    @ViewBuilder let still: (_ isPlaying: Bool) -> Still

    /// Nil outside the app's windows (previews): plays.
    @Environment(AppPreferences.self) private var preferences: AppPreferences?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False while a scroll view has it out of sight.
    @State private var isOnScreen = true

    var body: some View {
        let plays = url != nil && Self.plays(setting: preferences?.autoplaysMotion ?? true, reduceMotion: reduceMotion)
        ZStack {
            still(plays)
            if plays, isOnScreen, let url {
                MutedLoopVideo(url: url, fills: fills)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
    }

    /// Moving artwork plays by itself: the setting is on and Reduce Motion
    /// is off.
    nonisolated static func plays(setting: Bool, reduceMotion: Bool) -> Bool {
        setting && !reduceMotion
    }
}
