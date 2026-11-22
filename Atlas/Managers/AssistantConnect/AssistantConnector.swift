//
//  AssistantConnector.swift
//  Atlas
//

import AppKit
import Observation

/// What one-click Connect stands on (Settings → AI Assistants): which
/// assistants are on this Mac, how Atlas writes their settings and
/// restarts them, the project folder each was given per app, and the
/// assistant connected a moment ago, whose row offers Send a Test
/// Suggestion. DEBUG scenes and the unit test host swap in pretend files
/// and apps (`InMemoryAssistantConfig`, `PretendAssistantApps`).
@MainActor
@Observable
final class AssistantConnector {
    static let shared = AssistantConnector.makeShared()

    /// An assistant connected while Settings was open.
    struct FreshConnection: Hashable {
        var assistant: ConnectableAssistant
        var appID: StoreApp.ID
        var appName: String
        /// Absolute path, nil when connected without a project.
        var folder: String?
    }

    /// Send a Test Suggestion, and how it went.
    enum TestState: Hashable {
        case sending
        /// Claude Code made its calls; the suggestion is in Store Page.
        case arrived
        /// The prompt is on the clipboard for an assistant Atlas can't ask.
        case copied
        case failed(String)
    }

    var fresh: FreshConnection?
    var tests: [ConnectableAssistant: TestState] = [:]
    /// The connection sheet, when one is open.
    var connecting: AssistantConnectModel?

    @ObservationIgnored var config: any AssistantConfigWriting
    @ObservationIgnored var apps: any AssistantAppControlling
    @ObservationIgnored let folders: AssistantProjectFolders
    /// Whether Claude Code is on this Mac when the helper can't tell:
    /// its usual install places.
    @ObservationIgnored var claudeCodeFound: @MainActor () -> Bool = AssistantConnector.claudeCodeOnDisk
    /// The app Connect is for: the one open in the main window, else the
    /// account's first.
    @ObservationIgnored var currentApp: @MainActor (MCPServerController) async -> StoreApp? = AssistantConnector.selectedApp
    /// Told about each new Connect sheet; DEBUG scenes give it a pretend
    /// Open panel and folder check.
    @ObservationIgnored var configureModel: @MainActor (AssistantConnectModel) -> Void = { _ in }
    /// How long the assistant has to answer before Connect says why it
    /// might not have.
    @ObservationIgnored var answerTimeout: Duration = .seconds(30)
    /// How long Claude Code may take over its hello once it answered.
    @ObservationIgnored var helloTimeout: Duration = .seconds(180)
    /// Puts a prompt on the clipboard for an assistant Atlas can't ask;
    /// DEBUG scenes and tests leave the clipboard alone.
    @ObservationIgnored var copy: @MainActor (String) -> Void = AssistantConnector.copyToPasteboard

    init(config: any AssistantConfigWriting, apps: any AssistantAppControlling, folders: AssistantProjectFolders) {
        self.config = config
        self.apps = apps
        self.folders = folders
    }

    // MARK: - Reading

    /// Whether `assistant` is on this Mac.
    func isInstalled(_ assistant: ConnectableAssistant, launcher: ClaudeCodeLauncher?) -> Bool {
        switch assistant {
        case .claudeCode:
            if let launcher, launcher.helper.installation != nil { return true }
            return claudeCodeFound()
        case .claudeForMac, .cursor:
            return apps.isInstalled(assistant)
        }
    }

    /// The folder Connect gave `assistant`, for any app; the app's own
    /// first.
    func folder(of assistant: ConnectableAssistant, appID: StoreApp.ID?) -> String? {
        if let appID, let folder = folders.folder(for: assistant, appID: appID) { return folder }
        return folders.anyFolder(for: assistant)
    }

    // MARK: - Changing

    /// The sheet finished connecting.
    func didConnect(_ connection: FreshConnection) {
        fresh = connection
        tests[connection.assistant] = nil
    }

    /// Disconnect…: the pairing is revoked, so its token stops working,
    /// and Atlas's entry leaves the assistant's settings where Atlas may
    /// still write.
    func disconnect(_ assistant: ConnectableAssistant, server: MCPServerController, launcher: ClaudeCodeLauncher?) {
        server.disconnectAll(of: assistant.clientKind)
        if fresh?.assistant == assistant { fresh = nil }
        tests[assistant] = nil
        switch assistant {
        case .claudeCode:
            if let launcher { Task { await launcher.unregisterAtlas() } }
        case .claudeForMac, .cursor:
            config.removeAtlas(from: assistant)
        }
    }

    /// Send a Test Suggestion and Ask for a First Suggestion: Claude Code
    /// is asked for a subtitle, marked as a test, with Atlas's tools only;
    /// the others get the prompt on the clipboard to paste.
    func sendTest(_ assistant: ConnectableAssistant, appID: StoreApp.ID, appName: String, launcher: ClaudeCodeLauncher?) async {
        let prompt = AssistantConnectPrompts.testSuggestion(appName: appName)
        guard assistant.answersAtlas, let launcher else {
            copy(prompt)
            tests[assistant] = .copied
            return
        }
        tests[assistant] = .sending
        let folder = fresh?.folder ?? launcher.projectFolder(for: appID) ?? ProjectFolderPath.home
        guard let runID = await launcher.start(.test, appID: appID, appName: appName, prompt: prompt, folder: folder) else {
            tests[assistant] = .failed(launcher.helper.title)
            return
        }
        while launcher.run(runID)?.isActive == true {
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard let run = launcher.run(runID) else { return }
        if let failure = run.failure {
            tests[assistant] = .failed(failure.title)
        } else if run.atlasCalls > 0 {
            tests[assistant] = .arrived
        } else {
            tests[assistant] = .failed(String(localized: "It made no call to Atlas."))
        }
    }

    // MARK: - Defaults

    private static func makeShared() -> AssistantConnector {
        #if DEBUG
        if DebugScene.requestedID != nil || UnitTestHost.isRunning {
            let connector = AssistantConnector(
                config: InMemoryAssistantConfig(), apps: PretendAssistantApps(), folders: AssistantProjectFolders(defaults: nil)
            )
            connector.copy = { _ in }
            connector.claudeCodeFound = { true }
            return connector
        }
        #endif
        return AssistantConnector(
            config: AssistantConfigAccess(defaults: .standard),
            apps: LiveAssistantApps(),
            folders: AssistantProjectFolders(defaults: .standard)
        )
    }

    /// Claude Code's usual install places, as the helper looks for them.
    static func claudeCodeOnDisk() -> Bool {
        let home = ProjectFolderPath.home
        let candidates = [
            "\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
            "\(home)/.npm-global/bin/claude", "\(home)/.volta/bin/claude", "\(home)/.bun/bin/claude",
        ]
        return candidates.contains { FileManager.default.fileExists(atPath: $0) }
            || FileManager.default.fileExists(atPath: "\(home)/.claude")
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func selectedApp(_ server: MCPServerController) async -> StoreApp? {
        guard let workspace = server.workspace else { return nil }
        if let app = workspace.selectedApp() { return app }
        return try? await workspace.apps().first
    }
}
