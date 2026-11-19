//
//  SettingsDebugScenes.swift
//  Atlas
//

#if DEBUG
import CryptoKit
import SwiftUI

/// Settings DEBUG scenes (`-AtlasDebugScene <id>`), board 48: each opens
/// the real Settings window on one pane, with the design's two saved keys
/// (Northpier Studio in use, Brightline Apps without Sales and Trends) and
/// its glossary. The main window closes, so Settings is the only window.
///
/// - `set-general` (`set-general-login`: "Open Atlas at login" on),
///   `set-accounts` (`set-accounts-remove`: Remove… asked in place),
///   `set-suggestions`, `set-pricing`, `set-shots`, `set-notif`
///   (`set-notif-blocked`: turned off in System Settings), `set-pro`
///   (yearly), `set-free`, `set-privacy`.
/// - AI Assistants: `set-assistants` (an assistant connected),
///   `set-assistants-off` (the server off), `set-assistants-key` (an API
///   key), `set-assistants-none` (built-in only); the older `set-ai-*`
///   scenes keep the server's states (pairing, waiting, paired, connected,
///   disconnected, the activity), `set-translation` the key (and
///   `set-translation-rejected` one the vendor refuses), `cc-settings`
///   Claude Code's helper (`ClaudeCodeDebugScenes`).
enum SettingsDebugScenes {
    static let ids = [
        "set-general", "set-general-login", "set-accounts", "set-accounts-remove", "set-account",
        "set-assistants", "set-assistants-off", "set-assistants-key", "set-assistants-none",
        "set-translation", "set-translation-rejected",
        "set-ai-off", "set-ai-pair", "set-ai-waiting", "set-ai-on", "set-ai-connected", "set-ai-disc", "set-ai-log",
        "set-suggestions", "set-pricing", "set-shots", "set-notif", "set-notif-blocked", "set-pro", "set-free", "set-privacy",
        "cc-settings",
    ]

    static let brightlineIssuerID = "5e1f0a42-8d7b-4c19-9f6e-27b3d0c8e915"

    static func pane(for id: String) -> SettingsPane? {
        switch id {
        case "set-general", "set-general-login": .general
        case "set-accounts", "set-accounts-remove", "set-account": .accounts
        case "set-suggestions": .suggestions
        case "set-pricing": .pricing
        case "set-shots": .screenshots
        case "set-notif", "set-notif-blocked": .notifications
        case "set-pro", "set-free": .pro
        case "set-privacy": .privacy
        case _ where source(for: id) != nil: .assistants
        default: nil
        }
    }

    /// Where an AI Assistants scene's suggestions come from.
    static func source(for id: String) -> TranslationProvider? {
        switch id {
        case "set-assistants-key", "set-translation", "set-translation-rejected": .aiProvider
        case "set-assistants-none": .appleTranslation
        case _ where assistantsState(for: id) != nil: .assistant
        default: nil
        }
    }

    /// Whether the scene's pretend login item starts on.
    static func opensAtLogin(_ id: String) -> Bool {
        id == "set-general-login"
    }

    /// `set-accounts-remove` asks about Brightline Apps in place.
    static func removingKeyID(for id: String) -> String? {
        id == "set-accounts-remove" ? DebugFixtures.brightline.keyID : nil
    }

    /// The MCP server's state for an AI Assistants scene.
    static func assistantsState(for id: String) -> AssistantsDebugState? {
        switch id {
        case "set-ai-off", "set-assistants-off": .off
        // Both designs draw the sheet after Copy, waiting for the client.
        case "set-ai-pair", "set-ai-waiting": .pairing
        case "set-ai-on", "set-ai-connected", "set-assistants", "cc-settings": .paired
        case "set-ai-disc": .disconnected
        case "set-ai-log": .log
        default: nil
        }
    }

    /// Atlas Pro's state: `set-pro` owns the yearly plan, `set-free` none;
    /// nil leaves it to `-AtlasPro`.
    @MainActor
    static func proGate(for id: String?) -> ProGate? {
        switch id {
        case "set-pro":
            let renews = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2027, month: 11, day: 2))
            let entitlements = Entitlements(store: DebugProStore(owned: .subscribed(plan: .yearly, until: renews, isTrial: false)))
            entitlements.start()
            return ProGate(entitlements: entitlements)
        case "set-free":
            return ProGate(entitlements: Entitlements(store: DebugProStore()))
        default:
            return nil
        }
    }

    /// The saved keys a scene starts with: both sample keys for Settings,
    /// none elsewhere (the connect scenes start empty).
    static func credentialsStore(for id: String) -> DebugCredentialsStore {
        guard ids.contains(id) else { return DebugCredentialsStore() }
        return DebugCredentialsStore(keys: [
            AppStoreConnectCredentials(
                issuerID: DebugFixtures.issuerID,
                keyID: DebugFixtures.northpier.keyID,
                privateKeyPEM: P256.Signing.PrivateKey().pemRepresentation,
                teamName: DebugFixtures.northpier.name
            ),
            AppStoreConnectCredentials(
                issuerID: brightlineIssuerID,
                keyID: DebugFixtures.brightline.keyID,
                privateKeyPEM: P256.Signing.PrivateKey().pemRepresentation,
                teamName: DebugFixtures.brightline.name
            ),
        ])
    }

    /// An API key scene shows a saved Anthropic key as dots: one that
    /// works, or one `DebugAIProviderKeyChecker` rejects.
    static func secretStore(for id: String) -> InMemorySecretStore {
        switch id {
        case "set-translation", "set-assistants-key":
            InMemorySecretStore(secrets: [AIProviderVendor.anthropic.secretName: "sk-ant-debug"])
        case "set-translation-rejected":
            InMemorySecretStore(secrets: [AIProviderVendor.anthropic.secretName: DebugAIProviderKeyChecker.rejectedKey])
        default:
            InMemorySecretStore()
        }
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        return AnyView(Opener(id: id))
    }

    /// Fills in what the design shows, opens Settings on the scene's pane
    /// and closes the main window.
    private struct Opener: View {
        let id: String
        @Environment(AppSession.self) private var session
        @Environment(MCPServerController.self) private var server
        @Environment(TranslationPreferences.self) private var translation
        @Environment(AppPreferences.self) private var preferences
        @Environment(\.openSettings) private var openSettings
        @Environment(\.dismissWindow) private var dismissWindow

        var body: some View {
            Color.clear
                .task {
                    session.record(
                        KeyAccessCheck(appCount: DebugFixtures.apps.count, milliseconds: 182, salesAccess: .readable, date: .now),
                        for: DebugFixtures.northpier.keyID
                    )
                    session.record(
                        KeyAccessCheck(appCount: 3, milliseconds: 240, salesAccess: .notAllowed, date: .now),
                        for: DebugFixtures.brightline.keyID
                    )
                    translation.glossary = TranslationGlossary(terms: ["Lumen", "Lumen Plus", "Face ID", "iCloud", "Weekly Reflections"])
                    translation.sourceLocaleCode = "en-US"
                    if let source = SettingsDebugScenes.source(for: id) { translation.provider = source }
                    SettingsDebugScenes.assistantsState(for: id)?.apply(to: server)
                    if id == "set-privacy" {
                        // "3 confirmations are turned off."
                        preferences.acceptsAllWithoutAsking = true
                        preferences.confirmsDiscarding = false
                        preferences.confirmsPriceIncreases = false
                    }
                    NotificationsSettingsPane.debugPermission = id == "set-notif-blocked" ? .blocked : .allowed
                    SettingsNavigation.shared.pane = SettingsDebugScenes.pane(for: id) ?? .general
                    openSettings()
                    dismissWindow(id: "main")
                }
        }
    }
}
#endif
