//
//  SuggestionsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → Suggestions (board 48): how Atlas writes (the source
/// language, the tone, the names never translated), its own checks, how
/// accepting works, and what is never accepted for you.
struct SuggestionsSettingsPane: View {
    @Environment(TranslationPreferences.self) private var translation
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        @Bindable var translation = translation
        @Bindable var preferences = preferences
        Form {
            SettingsPaneHeader(pane: .suggestions)
            Section("Writing") {
                Picker(selection: $translation.sourceLocaleCode) {
                    Text("Each app’s primary language").tag(String?.none)
                    Divider()
                    ForEach(StoreLocaleCatalog.all) { locale in
                        Text(locale.name).tag(String?.some(locale.code))
                    }
                } label: {
                    SettingsRowLabel(title: "Source language", caption: String(localized: "Other languages are suggested from this one."))
                }
                .accessibilityIdentifier("settings.sourceLocale")
                Picker("Tone", selection: $translation.glossary.tone) {
                    ForEach(TranslationTone.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("settings.tone")
                VStack(alignment: .leading, spacing: Spacing.small) {
                    SettingsRowLabel(title: "Never translated", caption: String(localized: "Names that stay as they are in every language."))
                    GlossaryEditor(glossary: $translation.glossary)
                }
                .padding(.vertical, Spacing.xxSmall)
            }
            Section("Atlas’s own checks") {
                Toggle(isOn: $preferences.checksRepeatedWords) {
                    SettingsRowLabel(
                        title: "Words repeated between name, subtitle and keywords",
                        caption: String(localized: "Apple indexes each word once.")
                    )
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.checksRepeatedWords")
            }
            Section("Accepting") {
                Toggle(isOn: Binding(get: { !preferences.acceptsAllWithoutAsking }, set: { preferences.acceptsAllWithoutAsking = !$0 })) {
                    SettingsRowLabel(
                        title: "Ask before Accept All Languages and Accept All Pages",
                        caption: String(localized: "Shows what will be accepted, with a chance to untick.")
                    )
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.asksBeforeAcceptAll")
            }
            Section {
                SettingsLockedRow(title: "Prices")
                SettingsLockedRow(title: "App Privacy answers and the age rating")
                SettingsLockedRow(title: "App Compliance", caption: String(localized: "Trader status, ICP filing number, licences."))
            } header: {
                Text("Never accepted for you")
            } footer: {
                Text("These have legal or money consequences. Atlas suggests, and you accept each one.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.neverAccepted")
        }
        .formStyle(.grouped)
    }
}
