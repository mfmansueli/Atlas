//
//  NominationsDebugScenesTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Board 70's DEBUG scenes: one per state, each opening Nominations.
@MainActor
@Suite("Nominations · DEBUG scenes")
struct NominationsDebugScenesTests {
    @Test func everySceneIsListedOnceAndOpens() {
        let ids = NominationsDebugScenes.ids
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("ft-") })
        for id in ["ft-empty", "ft-gallery", "ft-new", "ft-submit", "ft-submitted", "ft-err-role", "ft-offline", "ft-s"] {
            #expect(ids.contains(id), "\(id)")
        }
        #expect(NominationsDebugScenes.view(for: "ft-gallery") != nil)
        #expect(NominationsDebugScenes.view(for: "ev-list") == nil)
        NominationsDebugLaunch.pending = nil
    }
}
