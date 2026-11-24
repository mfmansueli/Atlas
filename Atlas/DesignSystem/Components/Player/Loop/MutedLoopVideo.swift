//
//  MutedLoopVideo.swift
//  Atlas
//

import SwiftUI

/// SwiftUI's `MutedLoopVideoView`: a movie file on repeat, muted, without
/// controls. Use it through `AutoplayingLoop`, which plays it only when
/// the person lets moving artwork play.
struct MutedLoopVideo: NSViewRepresentable {
    let url: URL
    var fills = true
    var isPlaying = true

    func makeNSView(context _: Context) -> MutedLoopVideoView {
        let view = MutedLoopVideoView()
        update(view)
        return view
    }

    func updateNSView(_ view: MutedLoopVideoView, context _: Context) {
        update(view)
    }

    private func update(_ view: MutedLoopVideoView) {
        view.fills = fills
        view.load(url)
        view.isPlaying = isPlaying
    }
}
