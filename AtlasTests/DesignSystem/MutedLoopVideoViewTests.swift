//
//  MutedLoopVideoViewTests.swift
//  AtlasTests
//

import AppKit
import Testing
@testable import Atlas

/// A moving artwork's loop: muted, on repeat, playing only while it's in a
/// window and asked to, and never in the way of a click.
@MainActor
@Suite("Muted loop video")
struct MutedLoopVideoViewTests {
    private let movie = URL(fileURLWithPath: "/tmp/MutedLoopVideoViewTests-loop.mov")

    @Test func itPlaysOnlyInAWindowAndWhileAsked() {
        let view = MutedLoopVideoView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.load(movie)
        #expect(view.url == movie)
        // Not in a window yet (a card out of the list, a closed sheet).
        #expect(!view.isPlayerRunning)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120), styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView?.addSubview(view)
        #expect(view.isPlayerRunning)
        view.isPlaying = false
        #expect(!view.isPlayerRunning)
        view.isPlaying = true
        #expect(view.isPlayerRunning)
        view.removeFromSuperview()
        #expect(!view.isPlayerRunning)
    }

    @Test func clicksGoThroughToWhatIsUnder() {
        let view = MutedLoopVideoView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        #expect(view.hitTest(NSPoint(x: 10, y: 10)) == nil)
    }

    @Test func theSameFileKeepsPlaying() {
        let view = MutedLoopVideoView(frame: .zero)
        view.load(movie)
        view.load(movie)
        #expect(view.url == movie)
        let other = URL(fileURLWithPath: "/tmp/MutedLoopVideoViewTests-other.mov")
        view.load(other)
        #expect(view.url == other)
        view.fills = false
        #expect(!view.fills)
    }
}
