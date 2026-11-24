//
//  AtlasApp.swift
//  Atlas
//

import SwiftUI

@main
struct AtlasApp: App {
    /// Launching at login, the Dock icon, closing and quitting (boards
    /// 45–46), answered by `AtlasLifecycle`.
    @NSApplicationDelegateAdaptor(AtlasAppDelegate.self) private var appDelegate
    @State private var session = AppSession(store: Self.credentialsStore, defaults: Self.defaults)
    @State private var changes: ChangeQueue
    @State private var history: PushHistory
    @State private var push: PushController
    @State private var pricingModes = PricingModeStore(defaults: Self.defaults)
    @State private var preferences: AppPreferences
    @State private var translation: TranslationPreferences
    @State private var assistants: MCPServerController
    @State private var keyAssistant: KeyAssistantController
    @State private var launcher: ClaudeCodeLauncher
    @State private var suggestions: FieldSuggestionStore
    @State private var pro = Self.makeProGate()
    @State private var background: BackgroundWork
    @State private var loginItem = Self.makeLoginItem()

    init() {
        let changes = ChangeQueue(persistence: Self.changePersistence)
        let history = PushHistory(fileURL: Self.historyURL)
        _changes = State(initialValue: changes)
        _history = State(initialValue: history)
        let preferences = AppPreferences(defaults: Self.defaults)
        _preferences = State(initialValue: preferences)
        let push = PushController(queue: changes, history: history)
        if Self.watchesConnection { push.watchConnection(Self.networkWatcher) }
        _push = State(initialValue: push)
        let suggestions = FieldSuggestionStore(persistence: Self.suggestionPersistence)
        _suggestions = State(initialValue: suggestions)
        let background = BackgroundWork(
            push: push, changes: changes, suggestions: suggestions, preferences: preferences, defaults: Self.defaults
        )
        _background = State(initialValue: background)
        AtlasLifecycle.shared.configure(work: background, preferences: preferences, push: push, isActive: Self.keepsRunning)
        let translation = TranslationPreferences(defaults: Self.defaults, secrets: Self.secretStore)
        let keyAssistant = KeyAssistantController(
            service: Self.keyAssistantService,
            secrets: Self.secretStore,
            defaults: Self.defaults,
            translation: translation
        )
        let assistants = MCPServerController(server: Self.httpServer, secrets: Self.secretStore, defaults: Self.defaults, port: Self.mcpPort)
        assistants.keyAssistant = keyAssistant
        let launcher = ClaudeCodeLauncher(
            assistants: assistants, runner: Self.scriptRunner, defaults: Self.defaults, simulatorRunner: Self.simulatorRunner
        )
        TourTip.configureTipKit()
        #if DEBUG
        if let id = DebugScene.requestedID { ClaudeCodeDebugScenes.configure(launcher, for: id) }
        DebugSnapshot.startIfRequested()
        #endif
        if Self.continuesAutopilot {
            // A Claude Code that stops with captures left is started again.
            launcher.onRunEnded = { [weak launcher] session in
                guard let launcher else { return }
                Task { await AutopilotContinuation.sessionEnded(session, center: .shared, launcher: launcher) }
            }
            // Autopilot says when a run needs the person.
            AutopilotCenter.shared.onStageChange = { run, old in
                guard let turn = AutopilotTurn.turn(from: old, to: run.stage) else { return }
                AutopilotTurnNotifier.shared.post(turn, run: run, appName: AutopilotTurnNotifier.appName(of: run))
            }
        }
        // Claude Code ending while it draws an event's concepts: what
        // arrived goes on to Choose.
        // Settings → Notifications: a push that ended, concepts ready.
        if Self.continuesAutopilot {
            push.onFinished = { landed, failed in AtlasNotifications.pushFinished(landed: landed, failed: failed) }
            EventArtworkStudio.shared.onConceptArrived = { run in AtlasNotifications.conceptsArrived(run) }
        }
        let endsAutopilotSession = launcher.onRunEnded
        launcher.onRunEnded = { session in
            endsAutopilotSession?(session)
            EventArtworkStudio.shared.claudeRunEnded(session)
            PageShotsStudio.shared.claudeRunEnded(session)
            AssistantAskCenter.shared.runEnded(session)
            AssistantChatCenter.shared.runEnded(session, log: assistants.log)
        }
        _translation = State(initialValue: translation)
        _keyAssistant = State(initialValue: keyAssistant)
        _assistants = State(initialValue: assistants)
        _launcher = State(initialValue: launcher)
    }

    var body: some Scene {
        // One window: every app is a sidebar row, so a second window would
        // only duplicate the library and its requests.
        Window("Atlas", id: "main") {
            RootView()
                .environment(session)
                .environment(changes)
                .environment(history)
                .environment(push)
                .environment(pricingModes)
                .environment(preferences)
                .environment(translation)
                .environment(assistants)
                .environment(keyAssistant)
                .environment(launcher)
                .environment(suggestions)
                .environment(pro)
                .environment(AnalyticsStore.shared)
                .environment(ReviewsStore.shared)
                .environment(InAppEventsStore.shared)
                .environment(ProductPagesStore.shared)
                .environment(EventArtworkStudio.shared)
                .environment(PageShotsStudio.shared)
                .environment(ReleaseStore.shared)
                .environment(background)
                .environment(loginItem)
                .environment(\.keyChecker, Self.keyChecker)
                .environment(\.teamNameLookup, Self.teamNameLookup)
                // What the person owns of Pro, and every change to it.
                .task {
                    assistants.isPro = { [pro] in pro.entitlements.isPro }
                    pro.entitlements.start()
                }
                .frame(minWidth: Metrics.minimumWindowWidth, minHeight: Metrics.minimumWindowHeight - Metrics.windowToolbarHeight)
                // The local MCP server runs while Atlas is open, if
                // the person turned it on.
                .task { assistants.startIfEnabled() }
                // Whether the helper is there to start Claude Code.
                .task { await launcher.refreshHelper() }
        }
        .defaultSize(width: 1200, height: 780)
        // The window never gets smaller than RootView's minimum frame, even
        // from a size saved before the minimum grew.
        .windowResizability(.contentMinSize)
        .commands {
            WorkspaceCommands()
            AccountCommands(session: session, pro: pro)
            SidebarCommands()
            HelpCommands()
            QuitCommands()
            #if DEBUG
            DesignSystemCatalogCommands()
            #endif
        }

        Settings {
            SettingsView(
                opensPairing: Self.debugOpensPairing,
                scrollsToLog: Self.debugScrollsToLog,
                removingKeyID: Self.debugRemovingKeyID
            )
            .environment(SettingsNavigation.shared)
            .environment(NotificationPreferences.shared)
            .environment(session)
            .environment(history)
            .environment(pro)
            .environment(AnalyticsStore.shared)
            .environment(pricingModes)
            .environment(preferences)
            .environment(translation)
            .environment(assistants)
            .environment(keyAssistant)
            .environment(launcher)
            .environment(background)
            .environment(loginItem)
            .environment(\.keyChecker, Self.keyChecker)
            .environment(\.teamNameLookup, Self.teamNameLookup)
            .environment(\.aiProviderKeyChecker, Self.aiProviderKeyChecker)
        }

        // Atlas Help (board 49), opened with ⌘? or from the Help menu.
        Window("Atlas Help", id: HelpCommands.windowID) {
            HelpWindow()
                .environment(HelpNavigation.shared)
        }
        .defaultSize(width: 900, height: 640)
        .commandsRemoved()

        #if DEBUG
        // Rule zero: the design system drawn by itself (Debug → Design
        // System Catalog…, ⌥⌘D).
        Window("Design System Catalog", id: DesignSystemCatalogCommands.windowID) {
            DesignSystemCatalogView()
        }
        .defaultSize(width: 1000, height: 760)
        .commandsRemoved()
        #endif
    }

    /// The menu bar icon, the window that hides instead of closing, the
    /// checks on their own and asking before quitting mid-push: real
    /// launches only (and `mb-live`). Other DEBUG scenes and the unit
    /// tests' host are a plain window that quits when closed.
    private static var keepsRunning: Bool {
        #if DEBUG
        if let id = DebugScene.requestedID { return MenuBarDebugScenes.isLive(id) }
        if UnitTestHost.isRunning { return false }
        #endif
        return true
    }

    /// Whether “You’re offline” follows the Mac's real connection: real
    /// launches only, so DEBUG scenes (`banner-offline`) and the unit tests'
    /// host show the notices they set.
    private static let networkWatcher = NetworkPathWatcher()

    private static var watchesConnection: Bool {
        #if DEBUG
        if DebugScene.requestedID != nil || UnitTestHost.isRunning { return false }
        #endif
        return true
    }

    /// "Open Atlas at login": the real login item for real launches, a
    /// pretend one otherwise (`SettingsDebugScenes` may turn it on).
    private static func makeLoginItem() -> LoginItem {
        #if DEBUG
        if let id = DebugScene.requestedID { return .inMemory(isEnabled: SettingsDebugScenes.opensAtLogin(id)) }
        if UnitTestHost.isRunning { return .inMemory() }
        #endif
        return LoginItem()
    }

    /// Atlas Pro: the App Store's purchases. DEBUG builds are Pro
    /// without one, so scenes, UI tests and the person's own work aren't
    /// locked; `-AtlasPro free` starts Free with a store that
    /// charges nothing (`DebugProStore`), and `-AtlasPro store` asks
    /// the App Store as a release build does.
    private static func makeProGate() -> ProGate {
        #if DEBUG
        if let gate = SettingsDebugScenes.proGate(for: DebugScene.requestedID) { return gate }
        switch UserDefaults.standard.string(forKey: "AtlasPro") {
        case "free": return ProGate(entitlements: Entitlements(store: DebugProStore()))
        case "store": break
        default: return ProGate(entitlements: Entitlements(store: DebugProStore(), override: true))
        }
        #endif
        if everyoneIsPro { return ProGate(entitlements: Entitlements(store: StoreKitProStore(), override: true)) }
        return ProGate(entitlements: Entitlements(store: StoreKitProStore()), defaults: defaults)
    }

    /// TEMPORARY (2026-11-22): a TestFlight build where everyone is Pro,
    /// without a purchase. Set back to false (or remove) before a build
    /// that should sell Pro.
    private static let everyoneIsPro = true

    /// DEBUG scenes (and so UI tests) and the unit tests' host keep keys and
    /// secrets in memory, so they never read or overwrite the real ones in
    /// the Keychain. A test build signed differently from the person's app
    /// would otherwise ask for the login password at every read: one per
    /// paired assistant, AI provider key and key assistant, each launch.
    static var credentialsStore: any CredentialsStore {
        #if DEBUG
        if let id = DebugScene.requestedID { return SettingsDebugScenes.credentialsStore(for: id) }
        if UnitTestHost.isRunning { return DebugCredentialsStore() }
        #endif
        return KeychainCredentialsStore()
    }

    static var secretStore: any SecretStore {
        #if DEBUG
        if let id = DebugScene.requestedID { return SettingsDebugScenes.secretStore(for: id) }
        if UnitTestHost.isRunning { return InMemorySecretStore() }
        #endif
        return KeychainSecretStore()
    }

    /// DEBUG scenes never open a port for the MCP server, except
    /// `cc-live`, which runs the real Claude Code on a port of its own;
    /// nor does the unit tests' host (`UnitTestHost`).
    private static var httpServer: any LocalHTTPServing {
        #if DEBUG
        if UnitTestHost.isRunning { return DebugHTTPServer() }
        if let id = DebugScene.requestedID, !ClaudeCodeDebugScenes.isLive(id) { return DebugHTTPServer() }
        #endif
        return LocalHTTPServer()
    }

    private static var mcpPort: UInt16 {
        #if DEBUG
        if let id = DebugScene.requestedID, ClaudeCodeDebugScenes.isLive(id) { return ClaudeCodeDebugScenes.livePort }
        #endif
        return MCPEndpoint.defaultPort
    }

    /// DEBUG scenes start a pretend Claude Code that answers from canned
    /// lines, never the real one.
    private static var scriptRunner: any UnixScriptRunning {
        #if DEBUG
        if let id = DebugScene.requestedID { return ClaudeCodeDebugScenes.scriptRunner(for: id) }
        #endif
        return LiveUnixScriptRunner()
    }

    /// Autopilot's runs go on when Claude Code stops early; DEBUG scenes keep
    /// their own runs, never the real ones.
    private static var continuesAutopilot: Bool {
        #if DEBUG
        if DebugScene.requestedID != nil { return false }
        #endif
        return true
    }

    /// DEBUG scenes read a pretend Mac's simulators; nil uses the helper's
    /// runner.
    private static var simulatorRunner: (any UnixScriptRunning)? {
        #if DEBUG
        if let id = DebugScene.requestedID, !ClaudeCodeDebugScenes.isLive(id) { return DebugUnixScriptRunner.simulators }
        #endif
        return nil
    }

    /// DEBUG scenes check keys with canned answers, never with Apple.
    private static var keyChecker: any KeyChecker {
        #if DEBUG
        if let id = DebugScene.requestedID { return ConnectDebugScenes.keyChecker(for: id) }
        #endif
        return LiveKeyChecker()
    }

    /// DEBUG scenes name an added key's team from canned data, never
    /// from Apple.
    private static var teamNameLookup: any TeamNameLookup {
        #if DEBUG
        if DebugScene.requestedID != nil { return DebugTeamNameLookup() }
        #endif
        return LiveTeamNameLookup()
    }

    /// DEBUG scenes answer API key requests from canned data, never from
    /// the vendor.
    private static var keyAssistantService: any KeyAssistantService {
        #if DEBUG
        if DebugScene.requestedID != nil { return DebugKeyAssistantService() }
        #endif
        return LiveKeyAssistantService()
    }

    /// DEBUG scenes check AI provider keys with canned answers, never with
    /// the vendor.
    private static var aiProviderKeyChecker: any AIProviderKeyChecker {
        #if DEBUG
        if DebugScene.requestedID != nil { return DebugAIProviderKeyChecker() }
        #endif
        return LiveAIProviderKeyChecker()
    }

    /// `set-accounts-remove` opens on Remove… asked in place.
    private static var debugRemovingKeyID: String? {
        #if DEBUG
        DebugScene.requestedID.flatMap(SettingsDebugScenes.removingKeyID(for:))
        #else
        nil
        #endif
    }

    /// DEBUG scenes that open AI Assistants on the pairing sheet or the log.
    private static var debugOpensPairing: Bool {
        #if DEBUG
        DebugScene.requestedID.flatMap(SettingsDebugScenes.assistantsState(for:)) == .pairing
        #else
        false
        #endif
    }

    private static var debugScrollsToLog: Bool {
        #if DEBUG
        DebugScene.requestedID.flatMap(SettingsDebugScenes.assistantsState(for:)) == .log
        #else
        false
        #endif
    }

    /// DEBUG scenes keep pending changes, history and preferences in memory
    /// too, so they never touch the real ones.
    private static var isDebugScene: Bool {
        #if DEBUG
        DebugScene.requestedID != nil
        #else
        false
        #endif
    }

    private static var changePersistence: (any ChangeQueuePersistence)? {
        isDebugScene ? nil : FileChangeQueuePersistence()
    }

    private static var suggestionPersistence: (any FieldSuggestionPersistence)? {
        isDebugScene ? nil : FileFieldSuggestionPersistence()
    }

    private static var historyURL: URL? {
        isDebugScene ? nil : PushHistory.defaultFileURL
    }

    private static var defaults: UserDefaults? {
        isDebugScene ? nil : .standard
    }
}
