//
//  AnalyticsKPI.swift
//  Atlas
//

import Foundation

/// One of the four numbers at the top of Analytics → Overview (board 92)
/// that the funnel doesn't show: Rating, Proceeds, Active subscribers and
/// Crashes on the newest version. Each has a blue line saying where it
/// goes ("Reviews ›"), and without data says the same case as its card in
/// the strip ("None sold yet", "1.4 too new to tell").
struct AnalyticsKPI: Hashable, Sendable, Identifiable {
    enum Kind: String, Hashable, Sendable, CaseIterable {
        case rating
        case proceeds
        case subscribers
        case crashes
    }

    var kind: Kind
    var title: String
    /// "4.6 ★", "$6,040", "1,284", "6.8", or "—".
    var value: String
    /// The line under the number: "+7% · after Apple’s commission".
    var detail: String?
    var tone: PageCardTone = .neutral
    /// The blue line's words; nil when there's nowhere to go.
    var link: String?
    /// The whole sentence VoiceOver reads.
    var accessibilityText: String
    /// Still being read: a grey skeleton line instead of the number.
    var isLoading = false

    var id: Kind { kind }
}
