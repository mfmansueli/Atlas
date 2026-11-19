//
//  EventArtworkDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Every board 47 scene opens a view, and the scenes leave the studio the
/// way the design shows it.
@MainActor
@Suite("EventArtworkDebugScenes", .serialized)
struct EventArtworkDebugScenesTests {
    private var studio: EventArtworkStudio { .shared }

    private func load(_ id: String) {
        _ = EventArtworkDebugScenes.view(for: id)
        DebugEventArtworkSetup.pending = nil
        InAppEventsDebugLaunch.pending = nil
    }

    @Test(arguments: EventArtworkDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(EventArtworkDebugScenes.view(for: id) != nil)
        DebugEventArtworkSetup.pending = nil
        InAppEventsDebugLaunch.pending = nil
    }

    @Test func idsAreUniqueAndLeaveOthersAlone() {
        #expect(Set(EventArtworkDebugScenes.ids).count == EventArtworkDebugScenes.ids.count)
        // Suggest Everything's scenes come first and would hide these.
        #expect(Set(EventArtworkDebugScenes.ids).isDisjoint(with: InAppEventsDebugScenes.ids))
        #expect(Set(EventArtworkDebugScenes.ids).isDisjoint(with: EverythingDebugScenes.ids))
        #expect(EventArtworkDebugScenes.view(for: "ev-art") == nil)
    }

    @Test func theGalleryAndPageScenesOpenWhereTheBoardDoes() {
        _ = EventArtworkDebugScenes.view(for: "ev-list")
        #expect(InAppEventsDebugLaunch.pending?.opensEvent == false)
        _ = EventArtworkDebugScenes.view(for: "ev-menu")
        #expect(InAppEventsDebugLaunch.pending?.opensMenu == true)
        _ = EventArtworkDebugScenes.view(for: "ev-details")
        #expect(InAppEventsDebugLaunch.pending?.previewKind == .details)
        load("ev-event")
        #expect(studio.runs.values.first?.pickedID == nil)
        #expect(studio.presentedKey == nil)
    }

    @Test func theArtworkScenesLeaveTheirRun() {
        load("ev-making")
        #expect(studio.makingRuns.count == 1)
        load("ev-missing")
        #expect(studio.runs.isEmpty)
        load("ev-used")
        #expect(studio.runs.values.first?.used?.name == "Snowfall Path")
        #expect(studio.runs.values.first?.usedAt != nil)
        load("ev-view-redo")
        #expect(studio.runs.values.first?.revisingID == "a")
        load("ea-files")
        #expect(studio.runs.values.first?.picked?.source == .files)
    }
}
#endif
