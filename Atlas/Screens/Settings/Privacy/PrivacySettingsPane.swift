//
//  PrivacySettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → Privacy & Data (board 48): what leaves this Mac and where it
/// goes, and what Atlas keeps on it: the activity, what can be made again,
/// the "Don't ask again" choices, and removing every key and file.
struct PrivacySettingsPane: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppSession.self) private var session
    @Environment(TranslationPreferences.self) private var translation
    @Environment(MCPServerController.self) private var server
    var data = LocalDataStore.shared
    @State private var cacheSize: Int64?
    @State private var isShowingActivity = false
    @State private var isConfirmingClear = false
    @State private var isConfirmingRemoval = false

    var body: some View {
        Form {
            SettingsPaneHeader(pane: .privacy)
            Section("What leaves this Mac") {
                destination("To Apple", "What you push, signed on this Mac with your key and sent straight to App Store Connect.")
                destination("To your AI assistant", "Only what it asks for through the local server: text, captures, prices. Never a key.")
                destination(
                    "To an AI provider, with an API key",
                    "The text a suggestion is being written for, from this Mac to the provider you chose."
                )
                destination("To Atlas’s developer", "Nothing. Atlas has no analytics or crash reporting of its own.")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.privacy.leaves")
            Section("Kept on this Mac") {
                LabeledContent {
                    Button("Show…") { isShowingActivity = true }
                        .accessibilityIdentifier("settings.privacy.showActivity")
                } label: {
                    SettingsRowLabel(title: "Activity", caption: String(localized: "Every push, and every call an assistant made."))
                }
                LabeledContent {
                    Button("Clear…") { isConfirmingClear = true }
                        .disabled(cacheSize == 0)
                        .accessibilityIdentifier("settings.privacy.clear")
                } label: {
                    SettingsRowLabel(title: "Rendered images and ratings", caption: cacheCaption)
                }
                LabeledContent {
                    Button("Reset", action: preferences.resetConfirmations)
                        .disabled(preferences.turnedOffConfirmations == 0)
                        .accessibilityIdentifier("settings.privacy.resetConfirmations")
                } label: {
                    SettingsRowLabel(title: "“Don’t ask again” choices", caption: PrivacySettingsPane.confirmationsCaption(preferences.turnedOffConfirmations))
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Remove All Keys and Data…", role: .destructive) { isConfirmingRemoval = true }
                        .accessibilityIdentifier("settings.privacy.removeAll")
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .task { cacheSize = await data.cacheSize() }
        .sheet(isPresented: $isShowingActivity) {
            PrivacyActivitySheet()
        }
        .confirmationDialog("Clear rendered images and ratings?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive) {
                data.clearCaches()
                cacheSize = 0
            }
        } message: {
            Text("Atlas makes them again when it needs them. Your drafts, captures and suggestions stay.")
        }
        .alert("Remove all keys and data from this Mac?", isPresented: $isConfirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove and Quit", role: .destructive, action: removeEverything)
                .accessibilityIdentifier("settings.privacy.removeAll.confirm")
        } message: {
            Text("""
            Every App Store Connect key, API key and paired assistant is deleted from the Keychain, and every draft, \
            suggestion and change that wasn’t pushed is deleted. Atlas quits. Nothing changes in App Store Connect.
            """)
        }
    }

    private var cacheCaption: String {
        guard let cacheSize else { return String(localized: "Measuring…") }
        let size = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
        return String(localized: "\(size) · made again when needed.")
    }

    static func confirmationsCaption(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "Every confirmation is on.")
        case 1: String(localized: "1 confirmation is turned off.")
        default: String(localized: "\(count) confirmations are turned off.")
        }
    }

    private func destination(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.medium))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func removeEverything() {
        data.removeEverything(session: session, translation: translation, server: server)
        guard data.isLive else { return }
        NSApp.terminate(nil)
    }
}
