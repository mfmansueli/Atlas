//
//  ReviewRiskSiblingApp.swift
//  Atlas
//

import Foundation

/// One of the person's other apps, for 4.3: its store listing's subtitle
/// and description in each language, as App Store Connect has them.
struct ReviewRiskSiblingApp: Hashable, Sendable {
    var appID: String
    var name: String
    /// e.g. "en-US".
    var primaryLocale: String
    /// Store locale code → subtitle; languages without one are left out.
    var subtitles: [String: String] = [:]
    /// Store locale code → description.
    var descriptions: [String: String] = [:]

    /// The subtitle and description in `locale`, else in its primary
    /// language, with the locale used; nil without a description.
    func text(in locale: String) -> (text: String, locale: String)? {
        let used = descriptions[locale] != nil ? locale : primaryLocale
        guard let description = descriptions[used], !description.isEmpty else { return nil }
        let subtitle = subtitles[used] ?? ""
        return (subtitle.isEmpty ? description : "\(subtitle)\n\(description)", used)
    }
}
