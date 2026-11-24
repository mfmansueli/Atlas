//
//  MutedLoopVideoView.swift
//  Atlas
//

import AppKit
import AVFoundation

/// A movie file playing muted on repeat, the way the App Store plays an
/// event's or a header's loop, with no controls; clicks go through to
/// what's under it. It plays only while in a window, so a card scrolled out
/// of a list or a closed sheet stops it. Clear until its first frame, so
/// the still under it shows meanwhile.
final class MutedLoopVideoView: NSView {
    private let player = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private(set) var url: URL?

    /// Fills its frame (cropping) or fits in it.
    var fills = true {
        didSet { playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect }
    }

    /// False pauses it where it is.
    var isPlaying = true {
        didSet { updatePlayback() }
    }

    /// Whether the player is playing now, for tests.
    var isPlayerRunning: Bool { player.rate > 0 }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = .clear
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Plays `url` from the start on repeat; the same file keeps playing.
    func load(_ url: URL) {
        guard url != self.url else { return }
        self.url = url
        looper?.disableLooping()
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        updatePlayback()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updatePlayback()
    }

    /// Clicks reach the card, button or viewer under it.
    override func hitTest(_: NSPoint) -> NSView? { nil }

    private func updatePlayback() {
        if isPlaying, window != nil, url != nil {
            player.play()
        } else {
            player.pause()
        }
    }
}
