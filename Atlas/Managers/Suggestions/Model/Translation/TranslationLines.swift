//
//  TranslationLines.swift
//  Atlas
//

import Foundation

/// Which of board 77's two fixed lines a suggestion's card shows: MEANS
/// (what it says, in the interface language) and Sounds (how natural it
/// reads). Only for a language that isn't the interface's; keywords get
/// MEANS only, URLs nothing. A line shows only when the assistant sent
/// what it needs.
enum TranslationLines: Hashable, Sendable {
    case none
    case meansOnly
    case meansAndSounds

    /// `locale` is the suggestion's language, nil for a text that has none
    /// (App Information), which keeps a gloss as MEANS and nothing else.
    static func lines(locale: String?, kind: TranslationFieldKind, interfaceLanguage: String = InterfaceLanguage.code) -> TranslationLines {
        if kind == .url || kind == .choice { return .none }
        guard let locale else { return .meansOnly }
        if InterfaceLanguage.isSameLanguage(locale, interfaceLanguage) { return .none }
        return kind == .keywords ? .meansOnly : .meansAndSounds
    }

    var showsMeans: Bool { self != .none }
    var showsSounds: Bool { self == .meansAndSounds }
}
