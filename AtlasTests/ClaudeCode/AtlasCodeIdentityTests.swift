//
//  AtlasCodeIdentityTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Whether the Atlas on disk is still the one running, as macOS judges it
/// before running the helper.
@Suite("Atlas code identity")
struct AtlasCodeIdentityTests {
    @Test func aBuildSignedAsSomeoneElseIsAReplacement() {
        #expect(AtlasCodeIdentity(running: "com.lima.atlas", onDisk: "Atlas").isReplaced)
        #expect(AtlasCodeIdentity(running: "com.lima.atlas", onDisk: "com.lima.applocalizer").isReplaced)
    }

    /// A rebuild signed as Atlas again keeps the helper working.
    @Test func theSameSigningIdentifierIsntAReplacement() {
        #expect(!AtlasCodeIdentity(running: "com.lima.atlas", onDisk: "com.lima.atlas").isReplaced)
    }

    /// A signature that couldn't be read never blocks a run.
    @Test func anUnknownSideIsntAReplacement() {
        #expect(!AtlasCodeIdentity(running: nil, onDisk: "Atlas").isReplaced)
        #expect(!AtlasCodeIdentity(running: "com.lima.atlas", onDisk: nil).isReplaced)
        #expect(!AtlasCodeIdentity(running: nil, onDisk: nil).isReplaced)
    }

    /// The test host reads both sides, and they agree.
    @Test func theTestHostIsTheAtlasOnDisk() {
        let identity = AtlasCodeIdentity.current()
        #expect(identity.running != nil)
        #expect(identity.onDisk != nil)
        #expect(!identity.isReplaced)
    }

    @Test func theFailureSaysWhatToDo() {
        let failure = ClaudeCodeRunFailure.atlasReplaced(onDisk: "Atlas")
        #expect(failure.title == "Open Atlas again to start Claude Code")
        #expect(failure.detail.contains("a build signed as “Atlas”"))
        #expect(failure.detail.contains("quit Atlas"))
        #expect(!failure.canRetry)
        #expect(!failure.needsFolder)
        #expect(ClaudeCodeRunFailure.atlasReplaced(onDisk: nil).detail.contains("another build"))
        #expect(ClaudeCodeRunFailure.couldNotStart("x").canRetry)
    }
}
