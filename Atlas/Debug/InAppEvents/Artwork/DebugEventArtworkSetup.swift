//
//  DebugEventArtworkSetup.swift
//  Atlas
//

#if DEBUG
import Foundation

/// How an `ea-*` scene opens the artwork sheet: from a fresh Brief or the
/// run already in the studio, with the flow set the way the board draws it.
struct DebugEventArtworkSetup {
    /// Taken by the section when it makes the event's flow.
    @MainActor static var pending: DebugEventArtworkSetup?

    /// Make the Artwork… is pressed as the scene opens.
    var opensBrief = false
    var hasDesignSystem = true
    var configure: @MainActor (EventArtworkFlow) -> Void = { _ in }

    /// The flow's files are the scene's, and Claude Code never starts.
    @MainActor
    func apply(to flow: EventArtworkFlow) {
        flow.directory = DebugEventArtworkConcepts.directory
        flow.launch = { _, _ in UUID() }
        configure(flow)
    }
}
#endif
