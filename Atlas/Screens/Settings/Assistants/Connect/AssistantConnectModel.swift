//
//  AssistantConnectModel.swift
//  Atlas
//

import AppKit
import Observation

/// Connect's sheet (board 48, November 22 (2)), three steps:
///
/// 1. **Project folder**: dropped, chosen, or the one Atlas found; checked
///    for the Xcode project with this app's bundle ID. Connect Without a
///    Project skips it. Claude for Mac reads no folders, so its sheet
///    starts at 2.
/// 2. **Connect**: Atlas adds itself to the assistant (Claude Code's own
///    `claude mcp add` through the helper; the others' settings file),
///    starts it in the folder, and waits for its first message.
/// 3. **Say hello**: Claude Code's real reply to one prompt, typed in as
///    it arrives; for the others, which Atlas can't ask, what Atlas saw of
///    them and the prompt to paste.
///
/// No answer after `AssistantConnector.answerTimeout` shows the usual
/// reasons, each with its button.
@MainActor
@Observable
final class AssistantConnectModel: Identifiable {
    enum Step: Hashable {
        case folder
        case connecting
        case hello
        case failed
    }

    /// Step 2's three lines.
    enum Progress: Int, Hashable, CaseIterable {
        case adding = 1
        case starting
        case waiting
    }

    /// Step 3's message: nil text while the assistant is still writing.
    struct Hello: Hashable {
        var text: String?
        var date: Date
        /// Written by the assistant itself, not by Atlas.
        var isFromAssistant: Bool
    }

    let id = UUID()
    let assistant: ConnectableAssistant
    let app: StoreApp?

    var step: Step
    var progress: Progress = .adding
    /// A folder is being dragged over the drop area.
    var isDragOver = false
    /// The folder given, accepted or not.
    var verdict: ProjectFolderVerdict?
    var suggestion: AssistantFolderSuggestion?
    /// Connect Without a Project.
    var withoutProject = false
    /// Step 2 waits for the helper, which starts Claude Code, to be saved.
    var needsHelper = false
    var hello: Hello?
    var failure: AssistantConnectFailure?
    var helloRunID: ClaudeCodeRun.ID?

    @ObservationIgnored private let server: MCPServerController
    @ObservationIgnored private let launcher: ClaudeCodeLauncher?
    @ObservationIgnored private let connector: AssistantConnector
    /// The URL the sandbox gave access to: the folder, or the project
    /// dragged from Xcode's title.
    @ObservationIgnored private var grantedURL: URL?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Asks for a folder, starting in one: the Open panel, canned in
    /// tests.
    @ObservationIgnored var folderChooser: @MainActor (_ appName: String, _ start: String?) -> URL? = AssistantConnectModel.chooseFolder
    /// Reads a folder for the app's project; canned in DEBUG scenes, whose
    /// pretend Mac has no ~/Developer/Lumen.
    @ObservationIgnored var folderChecker: (_ url: URL, _ bundleID: String?) -> ProjectFolderVerdict = { ProjectFolderVerdict.check($0, bundleID: $1) }
    @ObservationIgnored var now: () -> Date = Date.init

    init(
        assistant: ConnectableAssistant,
        app: StoreApp?,
        server: MCPServerController,
        launcher: ClaudeCodeLauncher?,
        connector: AssistantConnector
    ) {
        self.assistant = assistant
        self.app = app
        self.server = server
        self.launcher = launcher
        self.connector = connector
        step = assistant.readsProject ? .folder : .connecting
        if assistant.readsProject { suggestion = findSuggestion() }
    }

    // MARK: - Reading

    var appName: String {
        app?.name ?? String(localized: "your app")
    }

    /// The steps the sheet lists.
    var stepTitles: [String] {
        let steps = [String(localized: "Connect"), String(localized: "Say hello")]
        return assistant.readsProject ? [String(localized: "Project folder")] + steps : steps
    }

    /// The step shown now, from 0.
    var stepIndex: Int {
        let index = switch step {
        case .folder: 0
        case .connecting, .failed: 1
        case .hello: 2
        }
        return assistant.readsProject ? index : max(index - 1, 0)
    }

    /// The accepted folder, absolute.
    var folder: String? {
        guard !withoutProject, let verdict, verdict.isAccepted else { return nil }
        return verdict.folder
    }

    var canConnect: Bool {
        folder != nil
    }

    /// Step 2's lines: "Adding Atlas to Cursor", "Starting Cursor in
    /// ~/Developer/Lumen", "Waiting for its first message".
    func progressTitle(_ line: Progress) -> String {
        switch line {
        case .adding: return String(localized: "Adding Atlas to \(assistant.title)")
        case .starting:
            guard let folder else { return String(localized: "Starting \(assistant.title)") }
            return String(localized: "Starting \(assistant.title) in \(ProjectFolderPath.abbreviated(folder))")
        case .waiting: return String(localized: "Waiting for its first message")
        }
    }

    /// The wrong folder's banner: what's missing and what to choose.
    var wrongFolderText: (title: String, detail: String)? {
        guard let verdict, !verdict.isAccepted, !withoutProject else { return nil }
        let expected = suggestion?.projectName ?? String(localized: "\(appName)’s .xcodeproj")
        switch verdict.outcome {
        case .noProject, .unreadable:
            return (
                String(localized: "“\(verdict.folderName)” has no Xcode project for \(appName)."),
                String(localized: "Choose the folder that holds \(expected), or a folder above it.")
            )
        case let .otherApp(project, bundleIDs):
            let builds = bundleIDs.prefix(2).formatted(.list(type: .and))
            return (
                String(localized: "“\(verdict.folderName)” holds \(project), which builds \(builds), not \(appName)."),
                String(localized: "Choose the folder that holds \(expected), or a folder above it.")
            )
        case .matches, .unchecked:
            return nil
        }
    }

    /// Step 1's checks once a folder is accepted.
    var folderChecks: [String] {
        guard let verdict, verdict.isAccepted else { return [] }
        var checks = [String(localized: "Xcode project found: \(verdict.projectName ?? verdict.folderName)")]
        if case .matches = verdict.outcome, let bundleID = app?.bundleID {
            checks.append(String(localized: "It’s the same app: \(bundleID)"))
        } else {
            checks.append(String(localized: "Its bundle ID comes from a build setting, so Atlas takes it as \(appName)’s."))
        }
        checks.append(assistant.folderAccessText)
        return checks
    }

    // MARK: - Step 1

    /// A folder (or Xcode project) dropped or chosen: checked at once.
    func use(_ url: URL) {
        isDragOver = false
        withoutProject = false
        grantedURL = url
        verdict = folderChecker(url, app?.bundleID)
    }

    /// Choose Folder…, starting where Atlas expects the project.
    func chooseFolder() {
        guard let url = folderChooser(appName, verdict?.folder ?? suggestion?.folder) else { return }
        use(url)
    }

    /// Use This Folder: the suggestion, or the Open panel on it when the
    /// sandbox doesn't let Atlas look inside yet.
    func useSuggestion() {
        guard let suggestion else { return }
        let url = URL(filePath: suggestion.folder, directoryHint: .isDirectory)
        if folderChecker(url, app?.bundleID).outcome == .unreadable {
            guard let chosen = folderChooser(appName, suggestion.folder) else { return }
            use(chosen)
        } else {
            use(url)
        }
    }

    /// Change…: back to the drop area.
    func changeFolder() {
        verdict = nil
        grantedURL = nil
    }

    /// Connect, or Connect Without a Project.
    func connect(withoutProject: Bool = false) {
        self.withoutProject = withoutProject
        rememberFolder()
        start()
    }

    // MARK: - Steps 2 and 3

    /// Starts (or starts again) step 2.
    func start() {
        task?.cancel()
        // Step 2 shows at once, before the first await.
        step = .connecting
        progress = .adding
        failure = nil
        task = Task { await run() }
    }

    /// Try Again and Restart and Try Again.
    func retry() {
        if let helloRunID { launcher?.stop(helloRunID) }
        start()
    }

    /// Cancel and Done: whatever is still going stops, the hello's run
    /// included (its words already arrived).
    func close() {
        task?.cancel()
        task = nil
        if let helloRunID, launcher?.run(helloRunID)?.isActive == true, hello?.text == nil { launcher?.stop(helloRunID) }
    }

    /// Install Helper…, when step 2 needs it; Connect goes on once it's
    /// saved and finds Claude Code.
    func installHelper() async {
        guard let launcher else { return }
        await launcher.installHelper()
        if launcher.canStart {
            needsHelper = false
            start()
        }
    }

    /// Ask for a First Suggestion: the same as the row's Send a Test
    /// Suggestion, so the row says when it arrived.
    func askForFirstSuggestion() {
        guard let app else { return }
        let connector = connector
        let launcher = launcher
        let assistant = assistant
        Task { await connector.sendTest(assistant, appID: app.id, appName: app.name, launcher: launcher) }
    }

    /// The prompt to paste into an assistant Atlas can't ask.
    func copyHelloPrompt() {
        connector.copy(AssistantConnectPrompts.pastedHello(appName: appName))
    }

    /// The hello's run, for Show Output.
    var helloRun: ClaudeCodeRun? {
        launcher?.run(helloRunID)
    }

    func run() async {
        step = .connecting
        progress = .adding
        failure = nil
        hello = nil
        needsHelper = false
        if let problem = await server.startForLaunch() {
            return fail(.couldNotAdd(problem))
        }
        guard let credentials = server.connectionCredentials(for: assistant.clientKind) else {
            return fail(.couldNotAdd(String(localized: "Atlas couldn’t save the connection’s key on this Mac.")))
        }
        switch assistant {
        case .claudeCode: await runClaudeCode(token: credentials.token)
        case .claudeForMac, .cursor: await runApp(clientID: credentials.clientID, token: credentials.token)
        }
    }

    private func runClaudeCode(token: String) async {
        guard let launcher, let app else { return fail(.couldNotAdd(String(localized: "Open an account in Atlas first."))) }
        guard await addAtlas(to: launcher, token: token), !Task.isCancelled else { return }
        progress = .starting
        if let folder { launcher.setProjectFolder(folder, for: app.id) }
        let prompt = AssistantConnectPrompts.hello(appName: app.name, readsProject: folder != nil)
        guard let runID = await launcher.start(
            .hello(readsProject: folder != nil), appID: app.id, appName: app.name, prompt: prompt, folder: folder ?? ProjectFolderPath.home
        ) else { return fail(.noAnswer) }
        helloRunID = runID
        progress = .waiting
        // Its first call to Atlas is its first message: the connection
        // works.
        await wait(connector.answerTimeout) { launcher.run(runID).map { $0.atlasCalls > 0 || $0.result != nil || !$0.isActive } ?? true }
        // An error result (not logged in, say) ends the run a moment later,
        // with the reason.
        if launcher.run(runID)?.result?.isError == true {
            await wait(.seconds(5)) { launcher.run(runID)?.isActive != true }
        }
        guard !Task.isCancelled, let run = launcher.run(runID) else { return }
        if let failure = run.failure { return fail(.run(failure)) }
        guard run.atlasCalls > 0 || run.result.map({ !$0.isError }) == true else {
            launcher.stop(runID)
            return fail(.noAnswer)
        }
        step = .hello
        hello = Hello(text: nil, date: now(), isFromAssistant: true)
        didConnect()
        await wait(connector.helloTimeout) { launcher.run(runID).map { $0.result != nil || !$0.isActive } ?? true }
        guard !Task.isCancelled, let ended = launcher.run(runID) else { return }
        showHello(of: ended, appName: app.name)
    }

    /// Claude Code's own `claude mcp add`, through the helper; false when
    /// the helper is needed first or the command failed.
    private func addAtlas(to launcher: ClaudeCodeLauncher, token: String) async -> Bool {
        if !launcher.canStart { await launcher.refreshHelper() }
        guard !Task.isCancelled else { return false }
        if !launcher.canStart, launcher.helper.installTitle != nil {
            needsHelper = true
            return false
        }
        if let problem = await launcher.registerAtlas(token: token, bridgePath: server.bridgePath) {
            fail(.couldNotAdd(problem))
            return false
        }
        return true
    }

    private func showHello(of run: ClaudeCodeRun, appName: String) {
        if let result = run.result, !result.isError, !result.text.isEmpty {
            hello = Hello(text: result.text, date: now(), isFromAssistant: true)
        } else if let failure = run.failure {
            fail(.run(failure))
        } else {
            hello = Hello(text: String(localized: "I’m connected to Atlas and can read \(appName)."), date: now(), isFromAssistant: true)
        }
    }

    private func runApp(clientID: MCPPairedClient.ID, token: String) async {
        do {
            try connector.config.addAtlas(to: assistant, token: token, bridgePath: server.bridgePath)
        } catch {
            // Atlas's own reasons read as they are; the system's go through the error template.
            let ownReason = error is AssistantConfigProblem || error is AssistantConfigFile.Problem
            let what = String(localized: "Atlas couldn’t add itself to \(assistant.title).", comment: "kind:error")
            return fail(.couldNotAdd(ownReason ? error.localizedDescription : AppleErrorCopy(what, error: error).text))
        }
        progress = .starting
        let folderURL: URL? = folder.map { path in grantedURL.map(Self.folderURL) ?? URL(filePath: path, directoryHint: .isDirectory) }
        guard await connector.apps.restart(assistant, folder: folderURL) else { return fail(.couldNotRestart) }
        guard !Task.isCancelled else { return }
        progress = .waiting
        await wait(connector.answerTimeout) { server.hasSession(for: clientID) }
        guard !Task.isCancelled else { return }
        guard server.hasSession(for: clientID) else { return fail(.noAnswer) }
        step = .hello
        let time = now().formatted(date: .omitted, time: .shortened)
        hello = Hello(
            text: String(localized: "\(assistant.title) connected at \(time). It can read \(appName) now."),
            date: now(),
            isFromAssistant: false
        )
        didConnect()
    }

    private func fail(_ failure: AssistantConnectFailure) {
        self.failure = failure
        step = .failed
    }

    private func didConnect() {
        guard let app else { return }
        connector.didConnect(.init(assistant: assistant, appID: app.id, appName: app.name, folder: folder))
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func wait(_ timeout: Duration, until condition: () -> Bool) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Folders

    private func rememberFolder() {
        guard let app else { return }
        if let folder {
            connector.folders.remember(folder, url: grantedURL.map(Self.folderURL), for: assistant, appID: app.id)
            launcher?.rememberApp(app.id, name: app.name)
        }
    }

    /// The folder for a URL that may be the project dragged from Xcode.
    private static func folderURL(_ url: URL) -> URL {
        ["xcodeproj", "xcworkspace"].contains(url.pathExtension) ? url.deletingLastPathComponent() : url
    }

    private func findSuggestion() -> AssistantFolderSuggestion? {
        guard let app else { return nil }
        var candidates: [AssistantFolderSuggestion.Candidate] = []
        if let folder = connector.folders.folder(for: assistant, appID: app.id) {
            candidates.append(.init(folder: folder, source: String(localized: "given to \(assistant.title) before")))
        }
        if let folder = launcher?.projectFolder(for: app.id) {
            candidates.append(.init(folder: folder, source: String(localized: "\(app.name)’s folder in Atlas")))
        }
        for session in server.sessions.reversed() {
            if let directory = session.workingDirectory {
                candidates.append(.init(folder: directory, source: String(localized: "\(session.displayName) works here")))
            }
        }
        for client in server.pairedClients.reversed() {
            if let directory = client.workingDirectory {
                candidates.append(.init(folder: directory, source: String(localized: "\(client.name) worked here")))
            }
        }
        if let folder = server.keyAssistant?.configuration?.projectFolderPath {
            candidates.append(.init(folder: folder, source: String(localized: "chosen for suggestions with an API key")))
        }
        return AssistantFolderSuggestion.first(of: candidates, bundleID: app.bundleID)
    }

    /// The Open panel for the project folder.
    static func chooseFolder(appName: String, start: String?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Use This Folder")
        panel.message = String(localized: "Choose \(appName)’s project folder, the one you open in Xcode.")
        if let start { panel.directoryURL = URL(filePath: start, directoryHint: .isDirectory) }
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
