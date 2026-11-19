//
//  GeneralSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → General (board 48): the appearance, Atlas in the menu bar
/// and the Dock (board 46), how often it checks App Store Connect, and the
/// confirmations before pushing.
struct GeneralSettingsPane: View {
    @Environment(AppPreferences.self) private var preferences
    /// Nil in previews.
    @Environment(LoginItem.self) private var loginItem: LoginItem?

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            SettingsPaneHeader(pane: .general)
            Section("Appearance") {
                LabeledContent("Appearance") {
                    FittingSegmentedPicker(
                        label: String(localized: "Appearance"),
                        options: AppAppearance.allCases.map { ($0, $0.title) },
                        selection: $preferences.appearance
                    )
                    .fixedSize()
                    .accessibilityIdentifier("settings.appearance")
                }
            }
            GeneralMenuBarSection(preferences: preferences, loginItem: loginItem)
            Section {
                Picker(selection: $preferences.checkInterval) {
                    ForEach(CheckInterval.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Check for reviews, status and reports")
                }
                .accessibilityIdentifier("settings.checkInterval")
            } header: {
                Text("Checking App Store Connect")
            } footer: {
                Text("Apple publishes analytics once a day, so reports are read each morning whatever you choose here.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            pushingSection
        }
        .formStyle(.grouped)
    }

    private var pushingSection: some View {
        @Bindable var preferences = preferences
        return Section("Before pushing") {
            LabeledContent {
                // Segments as wide as their titles, so the row stays one line.
                FittingSegmentedPicker(
                    label: String(localized: "Confirm before pushing"),
                    options: PushConfirmation.allCases.map { ($0, $0.title) },
                    selection: $preferences.pushConfirmation
                )
                .fixedSize()
                .accessibilityIdentifier("settings.pushConfirmation")
            } label: {
                SettingsRowLabel(
                    title: "Confirm before pushing",
                    caption: String(localized: "Review & Push always opens first. This adds a final “Push 26 changes?”")
                )
            }
            Toggle("Confirm before discarding changes", isOn: $preferences.confirmsDiscarding)
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.confirmsDiscarding")
            Toggle(isOn: $preferences.confirmsPriceIncreases) {
                SettingsRowLabel(
                    title: "Ask before pushing price increases",
                    caption: String(localized: "Shows how many subscribers would be asked to agree.")
                )
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.confirmsPriceIncreases")
        }
    }
}
