//
//  MCPPrompt+NativeTranslation.swift
//  Atlas
//

import Foundation

// The translating prompts: one native-speaker agent per language
// (`NativeTranslationFlow`). The Translate sheets send the same text, with
// the languages they picked.
extension MCPPrompt {
    /// `translate_missing`; with `locales`, the Translate sheet's request
    /// naming them, and `fields` when it asks for only some (of the empty
    /// ones in each language).
    static func translateMissingInstructions(appPhrase: String, locales: [StoreLocale]? = nil, fields: [ListingField]? = nil) -> String {
        let into = locales.map { " into \(NativeTranslationFlow.languageList($0))" } ?? ""
        let find = locales == nil ? ", then list_missing_translations for the languages and fields that are empty" : ""
        let steps = NativeTranslationFlow.coordinatorSteps(locales: locales, fields: fields?.map(\.rawValue), missingOnly: fields != nil)
        return """
        Translate the Store Page of \(appPhrase)\(into) with Atlas, one native-speaker agent per language, so each \
        language reads as if it were written in it. Call list_apps to get its appId\(find). \(steps) Brand and \
        product names and the glossary's terms stay as they are. \(StoreTextRules.summary) Leave out what breaks a \
        rule rather than translating it. The person reviews every suggestion in Atlas before it's pushed.
        """
    }

    /// `translate_captions`; with `locales`, the captions' Translate sheet's
    /// request naming them.
    static func translateCaptionsInstructions(appPhrase: String, locales: [StoreLocale]? = nil) -> String {
        let into = locales.map { " into \(NativeTranslationFlow.languageList($0))" } ?? ""
        let steps = NativeTranslationFlow.coordinatorSteps(locales: locales, fields: [TranslationBrief.captionsField])
        return """
        Use Atlas to translate the missing screenshot captions of \(appPhrase)\(into), one native-speaker agent per \
        language. Call list_apps to get its appId, then get_screenshot_context for the slots, the locales in scope \
        and the primary captions, and get_captions to find the slots without a caption. \(steps) Each language's \
        agent uses get_capture to see the screen a caption describes, writes natural, short marketing captions, keeps \
        brand names untranslated, checks each with measure_caption until it fits, and sends its language with \
        propose_captions in one call, saying why. \(StoreTextRules.summary) If an item is refused, read how much it’s \
        over, shorten it and propose again. The person accepts or rejects them in Atlas; nothing is pushed.
        """
    }
}
