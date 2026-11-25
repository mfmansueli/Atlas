//
//  NativeTranslationFlow.swift
//  Atlas
//

import Foundation

/// How Atlas asks for texts in several languages: the assistant
/// coordinates and one native-speaker agent writes each language
/// (`TranslationAgentPrompt`), at most `maxAgents` at a time, then a
/// second native reader per language judges how natural it sounds (board
/// 77). The MCP prompts, the server's instructions and the requests Atlas
/// builds in the app all say it with these words.
nonisolated enum NativeTranslationFlow {
    /// Agents running at once, writers and reviewers together: enough that
    /// a 12-language request finishes in a few rounds, few enough that the
    /// person's usage doesn't run away.
    static let maxAgents = 4

    /// Board 77's fields the reviewer adds to a suggestion: what it means
    /// in the interface language, how natural it sounds, the phrases that
    /// sound translated, and the whole natural version. Part E defines and
    /// checks them on the suggestion.
    static let reviewFields = ["means", "sounds", "notes", "natural"]

    /// "German, French and Japanese (de-DE, fr-FR, ja)".
    static func languageList(_ locales: [StoreLocale]) -> String {
        let names = locales.map(\.name).formatted(.list(type: .and).locale(Locale(identifier: "en")))
        return "\(names) (\(locales.map(\.code).joined(separator: ", ")))"
    }

    /// The coordinator's steps, after the request has said what to
    /// translate. `fields` are the fields asked for ("captions" too), or
    /// nil for every empty field; `missingOnly` keeps only the empty ones.
    static func coordinatorSteps(locales: [StoreLocale]?, fields: [String]?, missingOnly: Bool = false) -> String {
        let which = locales.map { "the locales [\($0.map(\.code).joined(separator: ", "))]" } ?? "the locales"
        let fieldsPart = fields.map { " and fields [\($0.joined(separator: ", "))]\(missingOnly ? " with missingOnly true" : "")" } ?? ""
        return """
        You coordinate and don't write the translations yourself: one native-speaker agent writes each language. Call \
        begin_translation once with \(which)\(fieldsPart). It starts a run Atlas counts by language and returns, per \
        language, the fields to write, a writer brief and a reviewer brief. Start one subagent per language with the \
        Agent tool, its prompt that language's writer brief exactly as given, at most \(maxAgents) agents at a time: start \
        the next as one finishes. Give each agent only its own language: it reads it with get_translation_brief and \
        sends it itself (suggest_fields for Store Page texts, propose_captions for captions), so each language's \
        suggestions show in Atlas as soon as it's done. When a language's writer is done, start its reviewer when \
        begin_translation gave one (it counts in the \(maxAgents)): a second native reader who adds \
        \(reviewFields.formatted(.list(type: .and).locale(Locale(identifier: "en")))) to each suggestion and ends the \
        language with end_suggestions and its locale. When every language has ended, call end_suggestions with the \
        run, then say per language what was sent and what was skipped. Without the Agent tool, do the same yourself, \
        one language at a time: the writer brief, then the reviewer brief.
        """
    }

    /// One sentence for the server's instructions.
    static let instructions = """
    To write texts in several languages, call begin_translation and start one subagent per language with its writer \
    brief, at most \(maxAgents) at a time: each is a native speaker who reads get_translation_brief and writes only its \
    own language, natively rather than word for word; then a second native reader per language adds \
    \(reviewFields.formatted(.list(type: .and).locale(Locale(identifier: "en")))) to each suggestion.
    """

    /// What Suggest Everything and Ask say about the languages beyond the
    /// primary one: native agents without begin_translation, on Suggest
    /// Everything's run when `withRun`.
    static func otherLanguages(withRun: Bool) -> String {
        let run = withRun ? " and the run" : ""
        let which = withRun ? "the fields of its locale in your plan" : "its fields"
        return """
        Write the primary language yourself. For every other language, the languages not on the App Store yet too, \
        start one native-speaker subagent per language with the Agent tool, at most \(maxAgents) at a time, and don't \
        write those languages yourself: tell each it's a native speaker and App Store copywriter of that language, to \
        call get_translation_brief with the appId and its locale\(run), to write \(which) natively, not word for word, \
        within their limits, and to send them with suggest_fields\(run), touching no other language.
        """
    }
}
