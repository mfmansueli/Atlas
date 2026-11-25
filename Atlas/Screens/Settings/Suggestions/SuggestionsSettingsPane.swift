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
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

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
                    SettingsRowLabel(title: "Never translated", caption: String(localized: "Names kept in every language."))
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
            Section("Assistant") {
                // Look for Improvements' runs are Pro; Atlas's own checks
                // above run for everyone.
                Toggle(isOn: $preferences.lookForImprovements) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                        SettingsRowLabel(
                            title: "Look for Improvements",
                            caption: String(localized: """
                            At most once a day per app, Claude Code looks at what Atlas found and leaves suggestions. \
                            It never pushes.
                            """, comment: "kind:hint")
                        )
                        if pro?.isFree == true { ProChip() }
                    }
                }
                .toggleStyle(.switch)
                .disabled(pro?.isFree == true)
                .accessibilityIdentifier("settings.lookForImprovements")
            }
            Section("Accepting") {
                Toggle(isOn: Binding(get: { !preferences.acceptsAllWithoutAsking }, set: { preferences.acceptsAllWithoutAsking = !$0 })) {
                    SettingsRowLabel(
                        title: "Ask before Accept All Languages and Accept All Pages",
                        caption: String(localized: "Lists what gets accepted; untick any.")
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
                Text("Legal or money consequences: Atlas suggests, you accept each one.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.neverAccepted")
        }
        .formStyle(.grouped)
    }
}
