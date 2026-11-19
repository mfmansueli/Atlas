//
//  GeneralMenuBarSection.swift
//  Atlas
//

import SwiftUI

/// Settings → General's "Menu bar and Dock" (board 46): the menu bar
/// icon, staying open when the window closes, the Dock, the icon's
/// animation and opening at login.
struct GeneralMenuBarSection: View {
    @Bindable var preferences: AppPreferences
    /// Nil in previews: the login row is left out.
    let loginItem: LoginItem?

    var body: some View {
        Section("Menu bar and Dock") {
            Toggle(isOn: $preferences.showsMenuBarIcon) {
                SettingsRowLabel(
                    title: "Show Atlas in the menu bar",
                    caption: String(localized: "What’s running and what needs you, one click away.")
                )
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.showsMenuBarIcon")
            Toggle(isOn: $preferences.keepsRunning) {
                SettingsRowLabel(
                    title: "Keep running when the window is closed",
                    caption: String(localized: "Pushes and Autopilot finish, and Atlas keeps checking for reviews and Apple’s answers.")
                )
            }
            .toggleStyle(.switch)
            // Without the icon there'd be no way back in.
            .disabled(!preferences.showsMenuBarIcon)
            .accessibilityIdentifier("settings.keepsRunning")
            Picker(selection: $preferences.dockVisibility) {
                ForEach(DockVisibility.allCases, id: \.self) { Text($0.title).tag($0) }
            } label: {
                Text("Show in the Dock")
            }
            .accessibilityIdentifier("settings.dockVisibility")
            Toggle(isOn: $preferences.animatesMenuBarIcon) {
                SettingsRowLabel(
                    title: "Animate the menu bar icon while working",
                    caption: String(localized: "Follows Reduce Motion.")
                )
            }
            .toggleStyle(.switch)
            .disabled(!preferences.showsMenuBarIcon)
            .accessibilityIdentifier("settings.animatesMenuBarIcon")
            if let loginItem {
                Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })) {
                    SettingsRowLabel(title: "Open Atlas at login", caption: String(localized: "Starts in the menu bar, with no window."))
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.opensAtLogin")
                .onAppear { loginItem.refresh() }
                if let problem = loginItem.problem {
                    InlineMessage.warning(problem)
                        .accessibilityIdentifier("settings.opensAtLogin.problem")
                }
            }
        }
        // The Dock icon follows at once, not at the next window change.
        .onChange(of: preferences.dockVisibility) { AtlasLifecycle.shared.windows.updateDockIcon() }
        .onChange(of: preferences.showsMenuBarIcon) { AtlasLifecycle.shared.windows.updateDockIcon() }
    }
}
