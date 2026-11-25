//
//  ReviewRiskPurposeString.swift
//  Atlas
//

import Foundation

/// One permission text (purpose string) as the project sets it: in an
/// Info.plist file or as an `INFOPLIST_KEY_…` build setting, and the
/// languages it's translated into.
struct ReviewRiskPurposeString: Hashable, Sendable {
    /// e.g. "NSCameraUsageDescription".
    var key: String
    /// The text in the development language, as written.
    var value: String
    /// Where it's set, for evidence: "Bruma/Info.plist:12".
    var place: String
    /// Languages with a translation (InfoPlist.xcstrings or
    /// *.lproj/InfoPlist.strings), as `ReviewRiskLanguageCode.base` gives them.
    var languages: Set<String> = []

    init(key: String, value: String, place: String, languages: Set<String> = []) {
        self.key = key
        self.value = value
        self.place = place
        self.languages = languages
    }

    /// Written: not empty once trimmed.
    var isWritten: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
