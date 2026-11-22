//
//  AssistantsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → AI Assistants (board 48): where suggestions come from (an
/// assistant over MCP, an API key, or Atlas's built-in checks). With an
/// assistant: the assistants found on this Mac, each connected with one
/// click and Connect's guided sheet (November 22), Advanced (connections
/// on or off, the line for any other assistant, Pair Assistant…), Claude
/// Code started by Atlas, what assistants may suggest and what they never
/// can, each app's Claude Design project, and the activity. Sections that
/// don't apply to the source chosen go away.
struct AssistantsSettingsPane: View {
    @Environment(MCPServerController.self) private var server
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(TranslationPreferences.self) private var translation
    @Environment(\.aiProviderKeyChecker) private var aiProviderKeyChecker
    @State private var connector = AssistantConnector.shared
    @State private var isPairing = false
    @State private var isShowingActivity: Bool
    @State private var showsAdvanced: Bool
    /// DEBUG scenes open on the pairing sheet.
    private let opensPairing: Bool

    init(opensPairing: Bool = false, scrollsToLog: Bool = false) {
        self.opensPairing = opensPairing
        _isShowingActivity = State(initialValue: scrollsToLog)
        _showsAdvanced = State(initialValue: Self.startsWithAdvanced)
    }

    var body: some View {
        @Bindable var translation = translation
        @Bindable var connector = connector
        ScrollViewReader { proxy in
            Form {
                SettingsPaneHeader(pane: .assistants)
                Section("Where suggestions come from") {
                    SuggestionSourceRow(
                        provider: .assistant, selection: $translation.provider,
                        badge: server.assistantStatus.isConnected ? String(localized: "Connected") : nil
                    )
                    SuggestionSourceRow(provider: .aiProvider, selection: $translation.provider) {
                        AIProviderKeyControls(keyStatus: AIProviderKeyStatusModel(checker: aiProviderKeyChecker))
                    }
                    SuggestionSourceRow(provider: .appleTranslation, selection: $translation.provider)
                }
                switch translation.provider {
                case .assistant:
                    AssistantsConnectSection(onConnect: connect)
                    AssistantsAdvancedSection(isExpanded: $showsAdvanced, onPair: pair)
                    if showsLauncher {
                        ClaudeCodeLauncherSection()
                            .id(Self.launcherID)
                    }
                    AssistantsPermissionsSection(server: server)
                    AssistantsDesignSection()
                    activitySection
                case .aiProvider:
                    KeyAssistantSettingsSection()
                case .appleTranslation:
                    EmptyView()
                }
            }
            .formStyle(.grouped)
            .task {
                #if DEBUG
                if Self.debugScrollsToLauncher { proxy.scrollTo(Self.launcherID, anchor: .top) }
                #endif
            }
        }
        .environment(connector)
        .sheet(item: $connector.connecting) { model in
            AssistantConnectSheet(model: model)
                .environment(connector)
        }
        .sheet(isPresented: $isPairing, onDismiss: server.cancelPairing) {
            PairAssistantSheet()
        }
        .sheet(isPresented: $isShowingActivity) {
            AssistantActivitySheet()
        }
        .task {
            // A DEBUG scene may have started the pairing already.
            guard opensPairing, server.isEnabled else { return }
            if server.pendingPairing == nil { server.beginPairing() }
            isPairing = true
        }
    }

    private static let launcherID = "settings.ai.launcher"

    #if DEBUG
    /// `cc-settings` opens on Claude Code's helper and folders.
    static var debugScrollsToLauncher = false
    /// `set-assistants-adv` opens with Advanced shown.
    static var debugShowsAdvanced = false
    #endif

    private static var startsWithAdvanced: Bool {
        #if DEBUG
        debugShowsAdvanced
        #else
        false
        #endif
    }

    /// Claude Code started by Atlas, and each app's folder: once Claude
    /// Code is connected or its helper saved.
    private var showsLauncher: Bool {
        server.pairedClient(of: .claudeCode) != nil || launcher.helper.isInstalled
    }

    private var activitySection: some View {
        Section("Activity") {
            LabeledContent {
                Button("Show Activity…") { isShowingActivity = true }
                    .accessibilityIdentifier("settings.ai.showActivity")
            } label: {
                SettingsRowLabel(title: "What assistants asked for", caption: AssistantActivitySheet.summary(of: server.log))
            }
        }
    }

    /// Connect: the sheet for the app open in the main window.
    private func connect(_ assistant: ConnectableAssistant) {
        Task {
            let app = await connector.currentApp(server)
            let model = AssistantConnectModel(assistant: assistant, app: app, server: server, launcher: launcher, connector: connector)
            connector.configureModel(model)
            connector.connecting = model
            // Claude for Mac reads no folder: Connect starts at once.
            if !assistant.readsProject { model.start() }
        }
    }

    private func pair() {
        server.beginPairing()
        isPairing = true
    }
}
