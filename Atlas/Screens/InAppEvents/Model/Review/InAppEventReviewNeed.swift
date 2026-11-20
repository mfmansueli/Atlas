//
//  InAppEventReviewNeed.swift
//  Atlas
//

import Foundation

/// Something App Store Connect needs on an event before it takes it to
/// App Review. Without a deep link it refuses the whole review submission
/// ("You must provide a value for the attribute 'deepLink'"), and the
/// version with it; with a date that has passed it refuses the event
/// ("Supplied date must be in the future"). The date rules are
/// `InAppEventDateRule`'s, one need each.
enum InAppEventReviewNeed: String, CaseIterable, Identifiable, Hashable, Sendable {
    case deepLink
    case primaryLocale
    case purpose
    case dates
    case eventEndBeforeStart
    case eventTooShort
    case eventTooLong
    case publishStartAfterEventStart
    case publishStartTooEarly
    case eventStartPassed
    case publishStartPassed
    case primaryTexts
    case languageTexts
    case card
    case details

    var id: String { rawValue }

    /// What's missing, in the footer's words: "add a deep link".
    var footerText: String {
        switch self {
        case .deepLink: String(localized: "add a deep link")
        case .primaryLocale: String(localized: "choose its primary language")
        case .purpose: String(localized: "choose its purpose")
        case .dates: String(localized: "set its dates")
        case .eventEndBeforeStart: String(localized: "end it after it starts")
        case .eventTooShort: String(localized: "make it last at least 15 minutes")
        case .eventTooLong: String(localized: "make it last 31 days at most")
        case .publishStartAfterEventStart: String(localized: "show its card by the time it starts")
        case .publishStartTooEarly: String(localized: "show its card at most 14 days before it starts")
        case .eventStartPassed: String(localized: "move its dates later")
        case .publishStartPassed: String(localized: "show its card from a time still ahead")
        case .primaryTexts: String(localized: "write its primary language")
        case .languageTexts: String(localized: "write every language")
        case .card: String(localized: "add the card image")
        case .details: String(localized: "add the details image")
        }
    }

    /// The banner's line: "No deep link: Open on the card has nowhere to
    /// go."
    var title: String {
        switch self {
        case .deepLink: String(localized: "No deep link: Open on the card has nowhere to go.")
        case .primaryLocale: String(localized: "No primary language: it’s what people see where the event isn’t translated.")
        case .purpose: String(localized: "No purpose: App Store Connect asks who the event is for.")
        case .dates: String(localized: "No dates: the event needs a start and an end.")
        case .eventEndBeforeStart, .eventTooShort, .eventTooLong, .publishStartAfterEventStart, .publishStartTooEarly, .eventStartPassed,
             .publishStartPassed:
            dateRule?.title ?? ""
        case .primaryTexts: String(localized: "The primary language’s name and descriptions aren’t all written.")
        case .languageTexts: String(localized: "A language has some of its texts, but not all three.")
        case .card: String(localized: "No event card (16:9) in any language.")
        case .details: String(localized: "No details page image (9:16) in any language.")
        }
    }

    /// How `get_in_app_events`' `missingForReview` names it.
    var mcpValue: String { rawValue }

    /// What `event` still needs, as App Store Connect has it, at `now`: a
    /// date that has passed, in any of its schedules, is one.
    static func needs(of event: InAppEvent, now: Date) -> [Self] {
        var needs: [Self] = []
        if InAppEventDetail.deepLink.value(in: event) == nil { needs.append(.deepLink) }
        if InAppEventDetail.primaryLocale.value(in: event) == nil { needs.append(.primaryLocale) }
        if event.purpose == nil { needs.append(.purpose) }
        if let rules = event.brokenDateRules(now: now) {
            needs += rules.map(Self.init)
        } else {
            needs.append(.dates)
        }
        let primary = event.primaryLocalization
        if primary?.isComplete != true { needs.append(.primaryTexts) }
        if event.localizations.contains(where: { $0.locale != primary?.locale && !$0.isComplete }) { needs.append(.languageTexts) }
        if event.media(.card) == nil { needs.append(.card) }
        if event.media(.details) == nil { needs.append(.details) }
        return needs
    }

    /// The need an art kind fills.
    init(_ kind: InAppEventMedia.Kind) {
        self = kind == .card ? .card : .details
    }

    /// The need of a date rule.
    init(_ rule: InAppEventDateRule) {
        self = switch rule {
        case .eventEndBeforeStart: .eventEndBeforeStart
        case .eventTooShort: .eventTooShort
        case .eventTooLong: .eventTooLong
        case .publishStartAfterEventStart: .publishStartAfterEventStart
        case .publishStartTooEarly: .publishStartTooEarly
        case .eventStartPassed: .eventStartPassed
        case .publishStartPassed: .publishStartPassed
        }
    }

    /// The date rule it is; nil for the others.
    var dateRule: InAppEventDateRule? {
        InAppEventDateRule(rawValue: rawValue)
    }

    /// The date field its fix starts at: the rule's, or the start when the
    /// event has no dates; nil for the needs that aren't about dates.
    var dateField: InAppEventDateField? {
        self == .dates ? .eventStart : dateRule?.field
    }

    /// The detail that fills it, for the ones an edit on the event's page
    /// fixes.
    var detail: InAppEventDetail? {
        switch self {
        case .deepLink: .deepLink
        case .primaryLocale: .primaryLocale
        case .purpose: .purpose
        case .dates, .eventEndBeforeStart, .eventTooShort, .eventTooLong, .publishStartAfterEventStart, .publishStartTooEarly, .eventStartPassed,
             .publishStartPassed, .primaryTexts, .languageTexts, .card, .details:
            nil
        }
    }
}
