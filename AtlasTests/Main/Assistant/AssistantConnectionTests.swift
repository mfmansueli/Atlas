//
//  AssistantConnectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What the overview's card says for the app on screen: connected in its
/// folder, in another app's, in one it wasn't given, refused for an old
/// token, ready for Atlas to start, or not connected.
@Suite("AssistantConnection")
struct AssistantConnectionTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let alba = (folder: "~/Projects/ios/Alba", appName: Optional("Alba"))
    private static let refused = MCPRefusedConnection(date: now.addingTimeInterval(-120), clientName: "Claude Code")

    private func state(
        appFolder: String? = "~/Projects/ios/SimProps",
        sessions: [String?] = [],
        refused: MCPRefusedConnection? = nil,
        canStart: Bool = false
    ) -> AssistantConnection.State {
        AssistantConnection.state(
            appFolder: appFolder, sessionFolders: sessions, otherApps: [Self.alba], refused: refused, canStart: canStart, lastSeen: nil
        )
    }

    private func connection(
        _ state: AssistantConnection.State,
        appFolder: String? = "~/Projects/ios/SimProps",
        startsRuns: Bool = false
    ) -> AssistantConnection {
        AssistantConnection(
            clientName: "Claude Code",
            appName: "SimProps",
            appFolder: appFolder,
            state: state,
            lastCall: Self.now.addingTimeInterval(-120),
            startsRuns: startsRuns
        )
    }

    // MARK: - State

    @Test func aSessionInTheAppsFolderOrInsideItIsConnectedHere() {
        #expect(state(sessions: ["~/Projects/ios/SimProps"]) == .connectedHere(folder: "~/Projects/ios/SimProps"))
        #expect(state(sessions: ["~/Projects/ios/Alba", "~/Projects/ios/SimProps/App/"]) == .connectedHere(folder: "~/Projects/ios/SimProps/App/"))
        // A folder whose name only starts the same isn't inside.
        #expect(state(sessions: ["~/Projects/ios/SimPropsKit"]) == .connectedElsewhere(folder: "~/Projects/ios/SimPropsKit", appName: nil))
    }

    /// The case from SimProps: Alba's Claude Code was connected, so the
    /// card said "connected" while SimProps's was refused.
    @Test func aRefusedTokenWinsOverAnotherAppsSession() {
        #expect(state(sessions: ["~/Projects/ios/Alba"], refused: Self.refused) == .refused(date: Self.refused.date, client: "Claude Code"))
        // The app's own session still says connected.
        #expect(state(sessions: ["~/Projects/ios/SimProps"], refused: Self.refused) == .connectedHere(folder: "~/Projects/ios/SimProps"))
    }

    @Test func anotherAppsFolderIsNamed() {
        #expect(state(sessions: ["~/Projects/ios/Alba"]) == .connectedElsewhere(folder: "~/Projects/ios/Alba", appName: "Alba"))
        #expect(state(appFolder: nil, sessions: ["~/Projects/ios/Alba"]) == .connectedElsewhere(folder: "~/Projects/ios/Alba", appName: "Alba"))
    }

    @Test func withoutAFolderTheAppCantTellItsOwn() {
        #expect(state(appFolder: nil, sessions: ["~/Projects/ios/SimProps"]) == .connectedUnsure(folder: "~/Projects/ios/SimProps"))
        #expect(state(appFolder: nil, sessions: [nil]) == .connectedUnsure(folder: nil))
    }

    @Test func nothingConnectedIsReadyOnlyWhenAtlasStartsIt() {
        #expect(state(canStart: true) == .readyToStart)
        #expect(state() == .notConnected(lastSeen: nil))
    }

    // MARK: - What it says

    @Test func connectedHereSaysTheProject() {
        let here = connection(.connectedHere(folder: "~/Projects/ios/SimProps"))
        #expect(here.title == "Claude Code is connected")
        #expect(here.detail(now: Self.now) == "Project ~/Projects/ios/SimProps · suggests only · last call 2 minutes ago")
        #expect(here.tone == .good)
        #expect(here.actions.isEmpty)
        #expect(here.canSuggestEverything)
    }

    @Test func refusedSaysWhyAndOffersReconnect() {
        let refused = connection(.refused(date: Self.refused.date, client: "Claude Code"))
        #expect(refused.title == "Claude Code can’t connect")
        #expect(refused.statusTitle == "Can’t connect")
        #expect(refused.detail(now: Self.now).hasPrefix("Refused 2 minutes ago: its token is from an older pairing."))
        #expect(refused.actions == [.reconnect])
        #expect(refused.tone == .problem)
        // Nothing to paste a prompt into, unless Atlas starts Claude Code.
        #expect(!refused.canSuggestEverything)
        #expect(connection(.refused(date: Self.now, client: nil), startsRuns: true).canSuggestEverything)
    }

    @Test func elsewhereSaysWhoseFolderAndWhatToDo() {
        let elsewhere = AssistantConnection.State.connectedElsewhere(folder: "~/Projects/ios/Alba", appName: "Alba")
        #expect(connection(elsewhere).title == "Claude Code is connected to another project")
        #expect(connection(elsewhere).detail(now: Self.now) == """
        It works in ~/Projects/ios/Alba, Alba’s project. Open it in ~/Projects/ios/SimProps to read SimProps’s code.
        """)
        let started = connection(elsewhere, startsRuns: true).detail(now: Self.now)
        #expect(started.hasSuffix("Suggest Everything starts it in ~/Projects/ios/SimProps for SimProps."))
        let unattached = connection(elsewhere, appFolder: nil)
        #expect(unattached.detail(now: Self.now).hasSuffix("Choose SimProps’s project folder so it reads the right code."))
        #expect(unattached.actions == [.chooseFolder])
        #expect(connection(elsewhere).tone == .attention)
    }

    @Test func unsureAsksForTheAppsFolder() {
        let unsure = connection(.connectedUnsure(folder: "~/Projects/ios/SimProps"), appFolder: nil)
        #expect(unsure.title == "Claude Code is connected")
        #expect(unsure.detail(now: Self.now) == "It works in ~/Projects/ios/SimProps. If that’s SimProps’s project, choose it as the app’s folder.")
        #expect(unsure.actions == [.chooseFolder])
    }

    @Test func readyAndNotConnectedSayWhereItRuns() {
        #expect(connection(.readyToStart).detail(now: Self.now) == "Atlas starts it in ~/Projects/ios/SimProps · suggests only")
        #expect(connection(.readyToStart, appFolder: nil).actions == [.chooseFolder])
        let off = connection(.notConnected(lastSeen: nil))
        #expect(off.title == "Claude Code isn’t connected")
        #expect(off.detail(now: Self.now) == "Open it in ~/Projects/ios/SimProps to connect · last call 2 minutes ago")
        #expect(!off.canSuggestEverything)
    }

    @Test func aUserAgentNamesTheClient() {
        #expect(MCPRefusedConnection.clientName(userAgent: "claude-code/2.1.316 (cli)") == "Claude Code")
        #expect(MCPRefusedConnection.clientName(userAgent: "claude-cli/2.1.316 (external, cli)") == "Claude Code")
        #expect(MCPRefusedConnection.clientName(userAgent: "Cursor/1.4") == "Cursor")
        #expect(MCPRefusedConnection.clientName(userAgent: "node") == nil)
        #expect(MCPRefusedConnection.clientName(userAgent: nil) == nil)
    }
}
