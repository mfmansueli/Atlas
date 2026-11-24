//
//  LanguageMenuGroup.swift
//  Atlas
//

import Foundation

/// A group of the language menu: Suggestions to review, Up to date, or the
/// languages that show the primary one's content ("Uses English (U.S.)
/// screenshots"). A switch that doesn't count suggestions has one group,
/// without a title.
struct LanguageMenuGroup: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case toReview
        case upToDate
        case usesPrimary
        case all
    }

    let kind: Kind
    let title: String?
    let entries: [LanguageBarEntry]

    var id: Kind { kind }
}
