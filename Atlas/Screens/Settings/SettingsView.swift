//
//  SettingsView.swift
//  Atlas
//

import SwiftUI

/// The Settings window (⌘,), board 48: a sidebar with search and nine
/// panes. Every pane edits shared objects from the environment
/// (`AppSession`, `AppPreferences`, `TranslationPreferences`,
/// `NotificationPreferences`…), so changes apply at once: there's no Save.
struct SettingsView: View {
    @Environment(SettingsNavigation.self) private var navigation
    @Environment(ProGate.self) private var pro: ProGate?
    @State private var query = ""

    /// DEBUG scenes open AI Assistants on the pairing sheet or the log, or
    /// Accounts asking to remove a key.
    private let opensPairing: Bool
    private let scrollsToLog: Bool
    private let removingKeyID: String?

    static let size = CGSize(width: 860, height: 640)

    init(opensPairing: Bool = false, scrollsToLog: Bool = false, removingKeyID: String? = nil) {
        self.opensPairing = opensPairing
        self.scrollsToLog = scrollsToLog
        self.removingKeyID = removingKeyID
    }

    var body: some View {
        @Bindable var navigation = navigation
        HStack(spacing: 0) {
            SettingsSidebar(selection: $navigation.pane, query: $query)
            Divider()
            pane(navigation.pane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(navigation.pane)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .sheet(item: Binding(get: { pro?.settingsPaywall }, set: { pro?.settingsPaywall = $0 })) { model in
            PaywallSheet(model: model) { continues in pro?.finish(model, continues: continues) }
        }
        // Without .contain the window's identifier replaces its rows'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.window")
    }

    @ViewBuilder
    private func pane(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .accounts: AccountsSettingsPane(removingKeyID: removingKeyID)
        case .assistants: AssistantsSettingsPane(opensPairing: opensPairing, scrollsToLog: scrollsToLog)
        case .suggestions: SuggestionsSettingsPane()
        case .pricing: PricingSettingsPane()
        case .screenshots: ScreenshotsSettingsPane()
        case .notifications: NotificationsSettingsPane()
        case .pro: ProSettingsPane()
        case .privacy: PrivacySettingsPane()
        }
    }
}
