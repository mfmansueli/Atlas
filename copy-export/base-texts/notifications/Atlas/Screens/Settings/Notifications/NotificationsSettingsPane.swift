//
//  NotificationsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → Notifications (board 48): whether macOS lets them through,
/// what Atlas tells you about, and how.
struct NotificationsSettingsPane: View {
    @Environment(NotificationPreferences.self) private var notifications
    @State private var permission: NotificationPermission?

    var body: some View {
        @Bindable var notifications = notifications
        Form {
            SettingsPaneHeader(pane: .notifications)
            if let permission {
                NotificationPermissionBanner(permission: permission)
            }
            Section("Tell me when") {
                toggle(
                    "Something needs me", caption: String(localized: "Autopilot or Claude is waiting for a choice."),
                    isOn: $notifications.needsYou, id: "needsYou"
                )
                toggle("App Review changes a version’s or an event’s status", isOn: $notifications.reviewStatus, id: "reviewStatus")
                toggle(
                    "A push finishes", caption: String(localized: "A push that fails always tells you."),
                    isOn: $notifications.pushFinished, id: "pushFinished"
                )
                Picker("New reviews", selection: $notifications.newReviews) {
                    ForEach(ReviewNoticeLevel.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("settings.notif.newReviews")
                Picker("Analytics has something new", selection: $notifications.analytics) {
                    ForEach(AnalyticsNoticeFrequency.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("settings.notif.analytics")
            }
            Section("How") {
                toggle("Play a sound", isOn: $notifications.playsSound, id: "sound")
                toggle("Show a dot on the menu bar icon", isOn: $notifications.showsMenuBarDot, id: "dot")
                toggle(
                    "Show the count on the Dock icon", caption: String(localized: "What needs you, not what’s suggested."),
                    isOn: $notifications.showsDockCount, id: "dock"
                )
            }
        }
        .formStyle(.grouped)
        .task { permission = await NotificationsSettingsPane.permission() }
        // Back from System Settings: read it again.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { permission = await NotificationsSettingsPane.permission() }
        }
    }

    private func toggle(_ title: LocalizedStringKey, caption: String? = nil, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            SettingsRowLabel(title: title, caption: caption)
        }
        .toggleStyle(.switch)
        .accessibilityIdentifier("settings.notif.\(id)")
    }

    private static func permission() async -> NotificationPermission {
        #if DEBUG
        if let debugPermission { return debugPermission }
        #endif
        return await AtlasNotifier.shared.permission()
    }

    #if DEBUG
    /// `set-notif` / `set-notif-blocked` show either banner.
    static var debugPermission: NotificationPermission?
    #endif
}
