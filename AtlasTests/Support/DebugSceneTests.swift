//
//  DebugSceneTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("DebugScene")
struct DebugSceneTests {
    @Test func readsTheIDAfterTheArgument() {
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "connect"]) == "connect")
    }

    @Test(arguments: [["Atlas"], ["Atlas", "-AtlasDebugScene"]])
    func noIDMeansANormalLaunch(arguments: [String]) {
        #expect(DebugScene.requestedID(in: arguments) == nil)
    }
}
