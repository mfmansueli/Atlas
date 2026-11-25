//
//  CaptionAssistantPrompt.swift
//  Atlas
//

import Foundation

/// What the captions' Translate sheet asks the assistant to fill the empty
/// captions: Claude Code's slash command for the server's
/// `translate_captions` prompt, and the same request in words, naming the
/// languages it picked, with the glossary and tone. One native-speaker
/// agent writes each language's captions, measures each and proposes them;
/// nothing is written until they're accepted.
struct CaptionAssistantPrompt: Hashable, Sendable {
    /// The MCP prompt's name (design README §5).
    static let promptName = "translate_captions"

    let appName: String
    let versionString: String
    let glossary: TranslationGlossary
    /// The languages with empty captions, in the sheet's order; empty for
    /// every one.
    var locales: [StoreLocale] = []

    /// "/mcp__atlas__translate_captions Lumen Journal".
    var slashCommand: String {
        "/mcp__\(MCPEndpoint.serverName)__\(Self.promptName) \(appName)"
    }

    /// "Use Atlas to translate the missing screenshot captions of Lumen
    /// Journal 1.4 into German and Polish (de-DE, pl), one native-speaker
    /// agent per language… Keep “Lumen” untranslated and keep the tone warm
    /// and simple."
    var text: String {
        let tone = glossary.tone.promptPhrase
        let keep = if glossary.terms.isEmpty {
            "Keep the tone \(tone)."
        } else {
            "Keep \(glossary.terms.map { "“\($0)”" }.formatted(.list(type: .and).locale(Locale(identifier: "en")))) untranslated "
                + "and keep the tone \(tone)."
        }
        let app = [appName, versionString].filter { !$0.isEmpty }.joined(separator: " ")
        return "\(MCPPrompt.translateCaptionsInstructions(appPhrase: app, locales: locales.isEmpty ? nil : locales)) \(keep)"
    }
}
