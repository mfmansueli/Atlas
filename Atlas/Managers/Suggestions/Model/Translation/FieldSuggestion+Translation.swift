//
//  FieldSuggestion+Translation.swift
//  Atlas
//

import Foundation

// Which of board 77's lines a field suggestion's card shows: MEANS and
// Sounds for a Store Page text in another language than the interface's,
// MEANS only for keywords, nothing for URLs and picked answers.
extension FieldSuggestion {
    /// The suggestion's language; nil for App Information's texts, which
    /// have none.
    var translationLocale: String? {
        switch target.scope {
        case let .storePage(locale), let .appPrivacy(locale): locale
        case .appInformation, .accessibility: nil
        }
    }

    var translationKind: TranslationFieldKind {
        switch target.scope {
        case .storePage:
            guard let field = ListingField(rawValue: target.field) else { return .text }
            if field == .keywords { return .keywords }
            return field.isURL ? .url : .text
        case .appPrivacy:
            return .url
        case .accessibility:
            return .choice
        case let .appInformation(page):
            return page == AppInformationPage.ageRating.rawValue ? .choice : .text
        }
    }

    func translationLines(interfaceLanguage: String = InterfaceLanguage.code) -> TranslationLines {
        TranslationLines.lines(locale: translationLocale, kind: translationKind, interfaceLanguage: interfaceLanguage)
    }

    /// Its card says Sounds off: Accept All Languages starts it unticked and
    /// never accepts it without asking.
    func soundsOff(interfaceLanguage: String = InterfaceLanguage.code) -> Bool {
        translationLines(interfaceLanguage: interfaceLanguage).showsSounds && layers?.soundsOff == true
    }
}
