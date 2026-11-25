//
//  InterfaceLanguage.swift
//  Atlas
//

import Foundation

/// The language Atlas is shown in, which MEANS is written in and whose
/// suggestions get no MEANS or Sounds line (board 77).
enum InterfaceLanguage {
    /// e.g. `en` or `pt-BR`.
    static var code: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// Whether two locale codes are the same language: `en-GB` and `en`
    /// are, `pt-BR` and `en` aren't.
    static func isSameLanguage(_ lhs: String, _ rhs: String) -> Bool {
        let left = Locale(identifier: lhs).language.languageCode?.identifier ?? lhs.lowercased()
        let right = Locale(identifier: rhs).language.languageCode?.identifier ?? rhs.lowercased()
        return left == right
    }
}
