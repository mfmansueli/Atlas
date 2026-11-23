//
//  NotificationPermissionBanner.swift
//  Atlas
//

import SwiftUI

/// The top of Settings → Notifications: allowed, or turned off for Atlas
/// in System Settings, with the way there.
struct NotificationPermissionBanner: View {
    let permission: NotificationPermission

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Image(systemName: isBlocked ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isBlocked ? Palette.warn : Palette.ok)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.notif.permission")
                Spacer(minLength: Spacing.small)
                Button("Open System Settings…") {
                    if let url = NotificationPermission.settingsURL { NSWorkspace.shared.open(url) }
                }
                .accessibilityIdentifier("settings.notif.openSystemSettings")
            }
            .listRowBackground(isBlocked ? Palette.warnTint : nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isBlocked ? "settings.notif.blocked" : "settings.notif.allowed")
    }

    private var isBlocked: Bool { permission == .blocked }

    private var message: String {
        switch permission {
        case .allowed:
            String(localized: "Notifications from Atlas are allowed.")
        case .notAsked:
            String(localized: "macOS asks the first time Atlas has something to tell you.")
        case .blocked:
            String(localized: """
            Notifications are turned off for Atlas in System Settings. Nothing below reaches you until they’re allowed. \
            The menu bar icon still shows a dot.
            """)
        }
    }
}
