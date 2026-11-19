//
//  AssistantsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → AI Assistants (board 48): where suggestions come from (an
/// assistant over MCP, an API key, or Atlas's built-in checks). With an
/// assistant: the local server, the paired assistants, Claude Code started
/// by Atlas, what assistants may suggest and what they never can, each
/// app's Claude Design project, and the activity. Sections that don't
/// apply to the source chosen go away.
struct AssistantsSettingsPane: View {
    @Environment(MCPServerController.self) private var server
    @Environment(TranslationPreferences.self) private var translation
    @Environment(\.aiProviderKeyChecker) private var aiProviderKeyChecker
    @State private var isPairing = false
    @State private var isShowingActivity: Bool
    /// DEBUG scenes open on the pairing sheet.
    private let opensPairing: Bool

    init(opensPairing: Bool = false, scrollsToLog: Bool = false) {
        self.opensPairing = opensPairing
        _isShowingActivity = State(initialValue: scrollsToLog)
    }

    var body: some View {
        @Bindable var translation = translation
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
                    serverSection
                    if server.isEnabled { pairedSection }
                    ClaudeCodeLauncherSection()
                        .id(Self.launcherID)
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
    #endif

    private var serverSection: some View {
        Section {
            Toggle(isOn: Binding(get: { server.isEnabled }, set: server.setEnabled)) {
                SettingsRowLabel(
                    title: "Let assistants connect",
                    caption: server.isEnabled ? server.statusText : String(localized: "Off. Paired assistants stay paired, and can’t connect.")
                )
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.ai.server")
        } header: {
            Text("Local server")
        } footer: {
            Text("""
            Runs on this Mac only, at \(server.address), and only while Atlas is running. Assistants read and suggest. They never \
            see your .p8 key and can’t push.
            """)
            .font(.caption)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pairedSection: some View {
        Section {
            if server.pairedClients.isEmpty {
                Text("Nothing paired yet. Pairing gives one assistant its own token, so you can revoke it without touching the others.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("settings.ai.noClients")
            }
            ForEach(server.pairedClients) { client in
                PairedClientRow(client: client, status: server.status(of: client)) {
                    server.revoke(client.id)
                }
            }
        } header: {
            HStack {
                Text("Paired assistants")
                Spacer()
                Button("Pair Assistant…", systemImage: "plus", action: pair)
                    .controlSize(.small)
                    .disabled(!server.isRunning)
                    .accessibilityIdentifier("settings.ai.pair")
            }
        }
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

    private func pair() {
        server.beginPairing()
        isPairing = true
    }
}
