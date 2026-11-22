//
//  AssistantConnectModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Connect's sheet over pretend settings files, apps and helper: the
/// folder step's checks, Atlas adding itself to each assistant, the hello,
/// and the no-answer state.
@MainActor
@Suite("AssistantConnectModel")
struct AssistantConnectModelTests {
    private let clock = TestClock()
    private let assistants: MCPServerController
    private let runner = FakeUnixScriptRunner()
    private let launcher: ClaudeCodeLauncher
    private let config = InMemoryAssistantConfig()
    private let apps = PretendAssistantApps()
    private let connector: AssistantConnector
    private let root: URL
    private let lumen = StoreApp(id: ClaudeCodeTestFixtures.lumenID, name: "Lumen Journal", bundleID: "dev.northpier.lumen", primaryLocale: "en-US")

    init() throws {
        assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock)
        connector = AssistantConnector(config: config, apps: apps, folders: AssistantProjectFolders(defaults: nil))
        // Long enough for a busy test host; the no-answer tests shorten it.
        connector.answerTimeout = .seconds(30)
        connector.helloTimeout = .seconds(30)
        connector.copy = { _ in }
        root = FileManager.default.temporaryDirectory.appending(path: "connect-\(UUID().uuidString)", directoryHint: .isDirectory)
        let project = root.appending(path: "Lumen/Lumen.xcodeproj", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("PRODUCT_BUNDLE_IDENTIFIER = dev.northpier.lumen;".utf8).write(to: project.appending(path: "project.pbxproj"))
        try FileManager.default.createDirectory(at: root.appending(path: "Downloads"), withIntermediateDirectories: true)
    }

    private func model(_ assistant: ConnectableAssistant) -> AssistantConnectModel {
        AssistantConnectModel(assistant: assistant, app: lumen, server: assistants, launcher: launcher, connector: connector)
    }

    private var lumenFolder: URL {
        root.appending(path: "Lumen", directoryHint: .isDirectory)
    }

    /// Waits until the sheet leaves step 2.
    private func waitForEnd(of model: AssistantConnectModel) async {
        for _ in 0..<3000 where model.step == .connecting || (model.step == .hello && model.hello?.text == nil) {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - Step 1

    @Test func claudeForMacReadsNoFolderSoItStartsAtConnect() {
        let model = model(.claudeForMac)
        #expect(model.step == .connecting)
        #expect(model.stepTitles == ["Connect", "Say hello"])
        #expect(model.stepIndex == 0)
        #expect(self.model(.cursor).stepTitles.count == 3)
    }

    @Test func theAppsFolderIsCheckedAndAccepted() {
        let model = model(.claudeCode)
        #expect(!model.canConnect)
        model.use(lumenFolder)
        #expect(model.canConnect)
        #expect(model.wrongFolderText == nil)
        #expect(model.folderChecks == [
            "Xcode project found: Lumen.xcodeproj",
            "It’s the same app: dev.northpier.lumen",
            "Claude Code may read this folder. It can’t write to it.",
        ])
        model.changeFolder()
        #expect(model.verdict == nil)
    }

    @Test func aWrongFolderSaysWhatIsMissing() throws {
        let model = model(.claudeCode)
        model.use(root.appending(path: "Downloads", directoryHint: .isDirectory))
        #expect(!model.canConnect)
        let wrong = try #require(model.wrongFolderText)
        #expect(wrong.title == "“Downloads” has no Xcode project for Lumen Journal.")
    }

    @Test func chooseFolderUsesThePanelsFolder() {
        let model = model(.claudeCode)
        model.folderChooser = { [lumenFolder] _, _ in lumenFolder }
        model.chooseFolder()
        #expect(model.folder?.hasSuffix("/Lumen") == true)
    }

    // MARK: - Cursor

    @Test func cursorGetsAtlasInItsSettingsAndConnects() async throws {
        let model = model(.cursor)
        apps.onRestart = { [assistants] assistant in
            guard let client = assistants.pairedClient(of: assistant.clientKind) else { return }
            assistants.sessions.append(Self.session(for: client.id))
        }
        model.use(lumenFolder)
        model.connect()
        await waitForEnd(of: model)
        #expect(model.step == .hello)
        let client = try #require(assistants.pairedClient(of: .cursor))
        #expect(config.token(of: .cursor) == assistants.tokens[client.id])
        #expect(apps.restarted.first?.folder?.lastPathComponent == "Lumen")
        #expect(model.hello?.isFromAssistant == false)
        #expect(connector.fresh?.assistant == .cursor)
        #expect(connector.fresh?.folder?.hasSuffix("/Lumen") == true)
        #expect(connector.folder(of: .cursor, appID: lumen.id)?.hasSuffix("/Lumen") == true)
    }

    @Test func noAnswerShowsTheReasons() async {
        connector.answerTimeout = .milliseconds(300)
        let model = model(.cursor)
        model.connect(withoutProject: true)
        await waitForEnd(of: model)
        #expect(model.step == .failed)
        #expect(model.failure == .noAnswer)
        #expect(model.progressTitle(.starting) == "Starting Cursor")
        #expect(apps.restarted.first?.folder == nil)
    }

    @Test func aSettingsFolderNotAllowedStopsAtAdding() async {
        config.problem = .notAllowed(.claudeForMac)
        let model = model(.claudeForMac)
        model.start()
        await waitForEnd(of: model)
        #expect(model.failure == .couldNotAdd(AssistantConfigProblem.notAllowed(.claudeForMac).localizedDescription))
        #expect(apps.restarted.isEmpty)
    }

    @Test func anAppThatWontQuitDidntAnswer() async {
        apps.restarts = false
        let model = model(.claudeForMac)
        model.start()
        await waitForEnd(of: model)
        #expect(model.failure == .couldNotRestart)
    }

    // MARK: - Claude Code

    @Test func claudeCodeIsAddedThroughTheHelperAndSaysHello() async throws {
        runner.lines = [
            ClaudeCodeTestFixtures.initLine(),
            ClaudeCodeTestFixtures.toolUseLine("mcp__atlas__get_store_page", id: "h1"),
            ClaudeCodeTestFixtures.resultLine(text: "Hi! I can see Lumen Journal."),
        ]
        await launcher.refreshHelper()
        let model = model(.claudeCode)
        model.use(lumenFolder)
        model.connect()
        await waitForEnd(of: model)
        #expect(model.step == .hello)
        #expect(model.hello?.text == "Hi! I can see Lumen Journal.")
        #expect(model.hello?.isFromAssistant == true)
        let client = try #require(assistants.pairedClient(of: .claudeCode))
        let token = try #require(assistants.tokens[client.id])
        let add = try #require(runner.recordedArguments.first { $0.contains("add") })
        #expect(Array(add.suffix(9)) == ["mcp", "add", "--scope", "user", "atlas", "--", MCPTestFixtures.bridgePath, "--token", token])
        let run = try #require(model.helloRun)
        #expect(run.purpose == .hello(readsProject: true))
        #expect(run.workingDirectory.hasSuffix("/Lumen"))
        #expect(run.prompt.hasPrefix("Read Lumen Journal with the atlas tools and the project folder"))
        #expect(launcher.projectFolder(for: lumen.id)?.hasSuffix("/Lumen") == true)
        #expect(connector.fresh?.assistant == .claudeCode)
    }

    @Test func withoutAProjectClaudeCodeOnlyReadsAtlas() async throws {
        runner.lines = [ClaudeCodeTestFixtures.initLine(), ClaudeCodeTestFixtures.resultLine(text: "Hi!")]
        await launcher.refreshHelper()
        let model = model(.claudeCode)
        model.connect(withoutProject: true)
        await waitForEnd(of: model)
        let run = try #require(model.helloRun)
        #expect(run.purpose == .hello(readsProject: false))
        #expect(run.purpose.permissions == .atlasOnly)
        #expect(run.workingDirectory == ProjectFolderPath.home)
    }

    @Test func withoutTheHelperConnectAsksToInstallIt() async {
        runner.helperExists = false
        let model = model(.claudeCode)
        model.use(lumenFolder)
        model.connect()
        for _ in 0..<100 where !model.needsHelper {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.needsHelper)
        #expect(model.step == .connecting)
        #expect(model.progress == .adding)
    }

    @Test func aClaudeCodeThatNeverCallsAtlasDidntAnswer() async {
        runner.lines = [ClaudeCodeTestFixtures.initLine()]
        // `claude mcp` answers; the hello's run never does.
        runner.onRun = { [runner] arguments in
            if arguments.contains("--name") { runner.exitStatus = nil }
        }
        await launcher.refreshHelper()
        connector.answerTimeout = .milliseconds(300)
        let model = model(.claudeCode)
        model.connect(withoutProject: true)
        await waitForEnd(of: model)
        #expect(model.step == .failed)
        #expect(model.failure == .noAnswer)
    }

    @Test func aLoginProblemIsItsOwnReason() async {
        runner.lines = [
            ClaudeCodeTestFixtures.initLine(),
            ClaudeCodeTestFixtures.resultLine(isError: true, text: "Invalid API key · Please run /login", apiErrorStatus: "401"),
        ]
        runner.onRun = { [runner] arguments in
            if arguments.contains("--name") { runner.exitStatus = 1 }
        }
        await launcher.refreshHelper()
        let model = model(.claudeCode)
        model.connect(withoutProject: true)
        await waitForEnd(of: model)
        #expect(model.step == .failed)
        guard case let .run(failure) = model.failure else {
            Issue.record("Expected the run's failure, got \(String(describing: model.failure))")
            return
        }
        #expect(failure.title == "Claude Code needs you to log in")
    }

    // MARK: - Helpers

    private static func session(for clientID: MCPPairedClient.ID) -> MCPClientSession {
        MCPClientSession(
            id: "s-\(clientID.uuidString)",
            pairedClientID: clientID,
            clientName: "cursor",
            displayName: "Cursor",
            protocolVersion: MCPProtocolVersion.latest,
            supportsRoots: false,
            connectedAt: .now,
            lastActivity: .now
        )
    }
}
