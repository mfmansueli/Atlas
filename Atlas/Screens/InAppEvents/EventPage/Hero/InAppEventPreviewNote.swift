//
//  InAppEventPreviewNote.swift
//  Atlas
//

import Foundation

/// The line under the event's preview (board 40): the concept previewed
/// when it isn't the one used, whose text it shows, and where the App
/// Store shows it. Purple while previewing a concept.
struct InAppEventPreviewNote: Hashable, Sendable {
    var text: String
    var isPreviewing: Bool

    static func make(
        previewing concept: String?, texts: InAppEventShownTexts, primaryLocale: String?, kind: InAppEventMedia.Kind, appName: String
    ) -> Self {
        var text = concept.map { String(localized: "Previewing “\($0)”, not chosen yet.") + " " } ?? ""
        let language = InAppEventChangeBuilder.localeName(texts.locale)
        let primary = primaryLocale.map(InAppEventChangeBuilder.localeName) ?? String(localized: "the primary language")
        switch texts.origin {
        case .suggestion:
            text += String(localized: "Text: the \(language) suggestion. Until you accept it, people there see \(primary).")
        case .fallback:
            text += String(localized: "No \(language) text yet, so people there see \(primary).")
        case .own:
            text += String(localized: "Text in \(language).")
        }
        text += " " + (kind == .card ? String(localized: "Search, Today and \(appName)’s page.") : String(localized: "The top of the event’s page."))
        return InAppEventPreviewNote(text: text, isPreviewing: concept != nil)
    }
}
