//
//  TranslationAgentPrompt.swift
//  Atlas
//

import Foundation

/// The prompts the coordinating assistant gives one language's agents,
/// as `begin_translation` returns them: the writer, a native speaker and
/// App Store copywriter who writes that language and nothing else, and the
/// reviewer, a second native reader who judges how natural each suggestion
/// sounds and adds board 77's fields (`NativeTranslationFlow.reviewFields`).
nonisolated enum TranslationAgentPrompt {
    /// The writer of `locale`. `fields` are the Store Page fields it
    /// writes; without any (captions only) there's no reviewer, so it ends
    /// its language itself.
    static func writer(app: String, appID: String, locale: StoreLocale, fields: [String], captions: Bool, run: String?) -> String {
        let hasReviewer = !fields.isEmpty
        let name = locale.name
        let runPart = run.map { ", run \($0)" } ?? ""
        var steps = [
            """
            You are a native \(name) speaker and an App Store copywriter for \(name)-speaking customers. Write \(app)'s \
            texts in \(name) (\(locale.code)) for Atlas, and nothing in any other language.
            """,
            """
            1. Call get_translation_brief with appId \(appID), locale \(locale.code)\(fieldsPart(fields))\(runPart). It has \
            the source texts, what \(name) has now, each field's limit, the words to keep, the words already approved in \
            \(name), the tone, market notes and App Review's rules.
            """,
            """
            2. Write each one as a \(name) copywriter would write it from scratch for this market: the same message and \
            facts, in natural \(name) phrasing, never word for word. Keep the app's name, trademarks and glossary.keep as \
            they are; use the words in glossary.approvedHere and the app's own \(name) interface words (projectStrings).
            """,
            """
            3. Stay within the limits: name and subtitle 30 characters, promotional text 170, description and What’s New \
            4000, keywords 100 bytes in UTF-8 as comma-separated terms without spaces (keywordRules). URLs are copied as \
            they are. Follow storeTextRules: no prices, “free” in any language, discounts or trials, no other platforms, \
            no “#1” or “best” in the name or subtitle, nothing “coming soon”.
            """,
        ]
        if !fields.isEmpty {
            steps.append("""
            4. Send the Store Page texts with suggest_fields: area store, locale \(locale.code)\(runPart), each item with \
            its value, a reason in the brief's interfaceLanguage (at most 110 characters, what makes it read naturally \
            in \(name)) and confidence. If one is refused, fix it as the reason says and send it again; run_stopped means \
            stop.
            """)
        }
        if captions {
            steps.append("""
            \(fields.isEmpty ? "4" : "5"). Do what the brief's captions says. Before you send them, read each caption once \
            more as a \(name) reader who hasn't seen the source, and rewrite what sounds translated.
            """)
        }
        let ending = hasReviewer || run == nil
            ? "Don't call end_suggestions: "
            : "Then call end_suggestions with run \(run ?? "") and locale \(locale.code), and "
        steps.append("""
        \(ending)reply with one line per field: sent, unchanged or skipped, and why. Never touch another language.
        """)
        return steps.joined(separator: "\n")
    }

    /// The reviewer of `locale`, a native reader who didn't write it.
    static func reviewer(app: String, appID: String, locale: StoreLocale, run: String?) -> String {
        let name = locale.name
        let runPart = run.map { ", run \($0)" } ?? ""
        let fields = NativeTranslationFlow.reviewFields
        let ending = run.map { "4. Then call end_suggestions with run \($0) and locale \(locale.code), and reply" } ?? "4. Reply"
        return [
            """
            You are a native \(name) reader who didn't write these texts. Review \(app)'s \(name) (\(locale.code)) \
            suggestions in Atlas, and nothing in any other language.
            """,
            """
            1. Call get_translation_brief with appId \(appID), locale \(locale.code)\(runPart): openSuggestions has the texts \
            suggested in \(name) a moment ago, with the source texts beside them.
            """,
            """
            2. Read each one first as a \(name) customer would on the App Store, before you compare it with the source. \
            Judge it: native (reads as written in \(name)), translated (the meaning is right, the phrasing is a \
            translation's) or off (a word changes the meaning, or there's a mistake).
            """,
            """
            3. Send each back with suggest_fields: area store, locale \(locale.code), the same field and the same value\(runPart), \
            adding \(fields[0]) (what it says, in the brief's interfaceLanguage, at most 220 characters), \(fields[1]) (native, \
            translated or off), \(fields[2]) (at most 2, each {phrase, natural, why}, why at most 110 characters) and, unless \
            it sounds native, \(fields[3]) (the whole text as you'd write it, within the same limit). Keep value as it is: \
            the person picks your version with Use Natural Version. Keywords get \(fields[0]) only, and URLs nothing. Skip a \
            field that's no longer in openSuggestions.
            """,
            "\(ending) with one line: how many sound native, translated and off.",
        ].joined(separator: "\n")
    }

    /// ", fields [subtitle, keywords]".
    private static func fieldsPart(_ fields: [String]) -> String {
        fields.isEmpty ? "" : ", fields [\(fields.joined(separator: ", "))]"
    }
}
