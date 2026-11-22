//
//  ScreenshotsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → Screenshots (board 48): the defaults an event's artwork
/// from Claude starts with. Each event can still choose in its
/// Brief.
struct ScreenshotsSettingsPane: View {
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            SettingsPaneHeader(pane: .screenshots)
            Section {
                Toggle(isOn: $preferences.opensCaptureRuns) {
                    SettingsRowLabel(
                        title: "Let Claude Code open capture-only runs",
                        caption: String(localized: """
                        When Claude Code asks to redo some captures, the run opens at once. Off: each request waits in \
                        Screenshots for Accept. Nothing is pushed either way.
                        """)
                    )
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.opensCaptureRuns")
            } header: {
                Text("Captures")
            }
            Section {
                Toggle(isOn: $preferences.eventArtworkHasWords) {
                    SettingsRowLabel(
                        title: "Words in event artwork",
                        caption: String(localized: "Off: the App Store writes the name over the image, so one pair works in every language.")
                    )
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.artworkWords")
                Toggle(isOn: $preferences.eventArtworkMakesMotion) {
                    SettingsRowLabel(title: "Also make moving versions", caption: String(localized: "A seamless 20-second loop of each image. Takes longer."))
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.artworkMotion")
            } header: {
                Text("Artwork")
            } footer: {
                Text("These are the defaults. Each event can still choose.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
        }
        .formStyle(.grouped)
    }
}
