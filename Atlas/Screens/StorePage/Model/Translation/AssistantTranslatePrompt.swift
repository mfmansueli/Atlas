//
//  AssistantTranslatePrompt.swift
//  Atlas
//

import Foundation

/// What the Translate sheet asks the assistant: Claude Code's slash command
/// for the server's `translate_missing` prompt, and the same request in
/// words, naming the languages and fields the sheet picked, for Claude Code
/// started by Atlas and any other MCP client. Either way one
/// native-speaker agent writes each language (`NativeTranslationFlow`).
struct AssistantTranslatePrompt: Hashable, Sendable {
    let appName: String
    let versionString: String
    let glossary: TranslationGlossary
    /// The languages picked, in the sheet's order; empty for every one.
    var locales: [StoreLocale] = []
    /// The fields picked; empty for every empty field.
    var fields: [ListingField] = []

    /// "/mcp__atlas__translate_missing Lumen Journal".
    var slashCommand: String {
        "\(MCPPrompt.translateMissing.slashCommand) \(appName)"
    }

    /// "Translate the Store Page of Lumen Journal 1.4 into German and
    /// Japanese (de-DE, ja) with Atlas, one native-speaker agent per
    /// language… Keep “Lumen” and “Face ID” untranslated and keep the tone
    /// warm and simple."
    var text: String {
        let tone = glossary.tone.promptPhrase
        let keep = if glossary.terms.isEmpty {
            "Keep the tone \(tone)."
        } else {
            "Keep \(glossary.terms.map { "“\($0)”" }.formatted(.list(type: .and).locale(Locale(identifier: "en")))) untranslated "
                + "and keep the tone \(tone)."
        }
        let app = [appName, versionString].filter { !$0.isEmpty }.joined(separator: " ")
        let request = MCPPrompt.translateMissingInstructions(
            appPhrase: app,
            locales: locales.isEmpty ? nil : locales,
            fields: fields.isEmpty ? nil : fields
        )
        return "\(request) \(keep)"
    }
}
