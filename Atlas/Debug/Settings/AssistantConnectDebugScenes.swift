//
//  AssistantConnectDebugScenes.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Board 48's one-click Connect (November 22), opened by
/// `SettingsDebugScenes` on AI Assistants with Lumen Journal as the app,
/// Claude Code, Claude for Mac and Cursor found on this pretend Mac, and
/// nothing written to the real assistants' settings:
///
/// - `set-assistants-new`: nothing connected yet, the three steps.
/// - `set-assistants-done`: Claude Code just connected in
///   ~/Developer/Lumen, with Send a Test Suggestion.
/// - `set-assistants-adv`: Claude Code and Cursor connected, Advanced
///   shown.
/// - Connect's sheet for Claude Code: `set-wiz-folder` (step 1 with the
///   folder Atlas found), `set-wiz-drag` (a folder dragged over),
///   `set-wiz-wrong` (Downloads, which has no project), `set-wiz-picked`
///   (Lumen's folder accepted), `set-wiz-busy` (step 2, starting it),
///   `set-wiz-hello` (step 3, its hello), `set-wiz-fail` (no answer).
///
/// The pretend helper answers Connect for real: Claude Code's registration
/// works and its hello run says hello, so Connect on `set-wiz-picked`
/// plays steps 2 and 3. A pretend Claude for Mac or Cursor connects a
/// second after it's restarted.
enum AssistantConnectDebugScenes {
    static let ids = [
        "set-assistants-new", "set-assistants-done", "set-assistants-adv",
        "set-wiz-folder", "set-wiz-drag", "set-wiz-wrong", "set-wiz-picked", "set-wiz-busy", "set-wiz-hello", "set-wiz-fail",
    ]

    static let lumenFolder = ProjectFolderPath.expanded("~/Developer/Lumen")

    /// The design's hello, for the still `set-wiz-hello`.
    static let hello = """
    Hi! I’m connected to Atlas and I can see Lumen Journal: version 1.4, 12 languages, 3 subscriptions. I also read your \
    project in ~/Developer/Lumen. It has weekly reflections and a mood calendar that the App Store page doesn’t mention yet. \
    Want me to suggest a new subtitle? You decide what to accept, and I can never push anything myself.
    """

    private static let testAnswer = "Suggested “Journal, mood and weekly reflections” as the subtitle, marked as a test."

    static func assistantsState(for id: String) -> AssistantsDebugState? {
        switch id {
        case "set-assistants-adv": .paired
        case "set-assistants-done", "set-wiz-hello": .justConnected
        case _ where ids.contains(id): .connectable
        default: nil
        }
    }

    /// The pretend helper: Claude Code found, `claude mcp` answering at
    /// once, and the hello and the test suggestion as runs.
    static func runner() -> DebugUnixScriptRunner {
        typealias Line = DebugUnixScriptRunner.Line
        typealias Stream = ClaudeCodeDebugStream
        var runner = DebugUnixScriptRunner()
        runner.script = DebugUnixScriptRunner.Script(lines: [Line(delay: .milliseconds(400), text: "Added stdio MCP server atlas to user config")])
        runner.scripts = [
            ClaudeCodeRunPurpose.hello(readsProject: true).title: DebugUnixScriptRunner.Script(lines: [
                Line(delay: .milliseconds(900), text: Stream.started()),
                Line(delay: .milliseconds(700), text: Stream.atlas("get_store_page", id: "h1")),
                Line(delay: .milliseconds(500), text: Stream.read(lumenFolder + "/CHANGELOG.md", id: "h2")),
                Line(delay: .milliseconds(1800), text: Stream.result(text: hello)),
            ]),
            ClaudeCodeRunPurpose.test.title: DebugUnixScriptRunner.Script(lines: [
                Line(delay: .milliseconds(400), text: Stream.started()),
                Line(delay: .milliseconds(600), text: Stream.atlas("suggest_fields", id: "t1")),
                Line(delay: .milliseconds(400), text: Stream.result(text: testAnswer)),
            ]),
        ]
        return runner
    }

    /// The pretend Mac and, for the sheet's scenes, the sheet in its state.
    @MainActor
    static func configure(_ id: String, server: MCPServerController, launcher: ClaudeCodeLauncher) {
        guard ids.contains(id) else { return }
        let connector = AssistantConnector.shared
        connector.currentApp = { _ in DebugFixtures.lumen }
        connector.claudeCodeFound = { true }
        if let apps = connector.apps as? PretendAssistantApps {
            apps.onRestart = { [weak server] assistant in
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    guard let server, let client = server.pairedClient(of: assistant.clientKind) else { return }
                    server.sessions.append(session(for: client))
                }
            }
        }
        connector.configureModel = { model in
            model.folderChooser = { _, _ in URL(filePath: lumenFolder, directoryHint: .isDirectory) }
            model.folderChecker = { url, _ in
                let folder = url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return folder == lumenFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    ? ProjectFolderVerdict(folder: lumenFolder, outcome: .matches(project: "Lumen.xcodeproj"))
                    : ProjectFolderVerdict(folder: url.path(percentEncoded: false), outcome: .noProject)
            }
            if model.assistant.readsProject {
                model.suggestion = AssistantFolderSuggestion(
                    folder: lumenFolder, projectName: "Lumen.xcodeproj", source: String(localized: "Claude Code worked here")
                )
            }
        }
        AssistantsSettingsPane.debugShowsAdvanced = id == "set-assistants-adv"
        if id == "set-assistants-done" {
            connector.didConnect(.init(assistant: .claudeCode, appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", folder: lumenFolder))
        }
        guard id.hasPrefix("set-wiz-") else { return }
        let model = AssistantConnectModel(assistant: .claudeCode, app: DebugFixtures.lumen, server: server, launcher: launcher, connector: connector)
        connector.configureModel(model)
        setUp(model, for: id, connector: connector)
        connector.connecting = model
    }

    @MainActor
    private static func setUp(_ model: AssistantConnectModel, for id: String, connector: AssistantConnector) {
        let picked = ProjectFolderVerdict(folder: lumenFolder, outcome: .matches(project: "Lumen.xcodeproj"))
        switch id {
        case "set-wiz-drag":
            model.isDragOver = true
        case "set-wiz-wrong":
            model.verdict = ProjectFolderVerdict(folder: ProjectFolderPath.expanded("~/Downloads"), outcome: .noProject)
        case "set-wiz-picked":
            model.verdict = picked
        case "set-wiz-busy":
            model.verdict = picked
            model.step = .connecting
            model.progress = .starting
        case "set-wiz-hello":
            model.verdict = picked
            model.step = .hello
            model.hello = .init(text: hello, date: .now, isFromAssistant: true)
            connector.didConnect(.init(assistant: .claudeCode, appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", folder: lumenFolder))
        case "set-wiz-fail":
            model.verdict = picked
            model.step = .failed
            model.failure = .noAnswer
        default:
            break
        }
    }

    private static func session(for client: MCPPairedClient) -> MCPClientSession {
        MCPClientSession(
            id: "debug-\(client.kind.rawValue)",
            pairedClientID: client.id,
            clientName: client.kind.rawValue,
            clientVersion: "1.0",
            displayName: client.name,
            protocolVersion: MCPProtocolVersion.latest,
            supportsRoots: false,
            connectedAt: .now,
            lastActivity: .now,
            hasOpenStream: true
        )
    }
}
#endif
