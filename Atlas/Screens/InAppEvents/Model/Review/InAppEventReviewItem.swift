//
//  InAppEventReviewItem.swift
//  Atlas
//

import Foundation

/// One line of an event's "Before App Review" list: what App Store
/// Connect still needs (`InAppEventReviewNeed`), or a deep link the app
/// doesn't claim, and whether something waiting in Review & Push (or an
/// assistant's suggestion) already fills it.
struct InAppEventReviewItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case need(InAppEventReviewNeed)
        /// The app's project doesn't claim the deep link's scheme or
        /// domain: `alba://`.
        case linkNotClaimed(String)
    }

    enum State: String, Hashable, Sendable {
        case missing
        /// A change waiting in Review & Push fills it once pushed.
        case queued
        /// An assistant's suggestion fills it once accepted.
        case suggested
    }

    var kind: Kind
    var state: State
    var text: String
    var detail: String?
    /// Dates that fix it, for its button ("Show from Nov 21, 3:00 PM") and
    /// `get_in_app_events`' `suggested`.
    var suggestedDates: [InAppEventDateField: Date] = [:]

    var id: String {
        switch kind {
        case let .need(need): need.rawValue
        case .linkNotClaimed: "linkNotClaimed"
        }
    }

    var need: InAppEventReviewNeed? {
        if case let .need(need) = kind { return need }
        return nil
    }

    /// `get_in_app_events`' name for it.
    var mcpValue: String { id }

    /// "Waits in Review & Push", "Suggested by Claude Code · accept it below".
    var stateText: String? {
        switch state {
        case .missing: nil
        case .queued: String(localized: "Waits in Review & Push")
        case .suggested: String(localized: "Suggested · accept it below")
        }
    }

    /// What waits for an event and fills its items once pushed or
    /// accepted: `details` the detail changes, `dates` the dates change,
    /// `missingArt` the kinds no art fills even counting what waits,
    /// `draftedLocales` the languages with texts waiting,
    /// `hasSuggestedTexts` whether an assistant suggested texts.
    struct Waiting: Hashable, Sendable {
        var details: [InAppEventDetail: PendingChange] = [:]
        var dates: PendingChange?
        var missingArt: [InAppEventMedia.Kind] = []
        var draftedLocales: Set<String> = []
        var hasSuggestedTexts = false

        /// What waits in Review & Push for `event`: art counts as there
        /// when some waits.
        init(for event: InAppEvent, changes: [PendingChange], builder: InAppEventChangeBuilder, hasSuggestedTexts: Bool = false) {
            let queuedArt = Set(builder.queuedArtwork(for: event.id, in: changes).map(\.kind))
            details = builder.queuedDetails(for: event.id, in: changes)
            dates = builder.queuedDates(for: event.id, in: changes)
            missingArt = InAppEventMedia.Kind.allCases.filter { event.media($0) == nil && !queuedArt.contains($0) }
            draftedLocales = Set(builder.drafts(for: event.id, in: changes).filter { !$0.value.isEmpty }.keys)
            self.hasSuggestedTexts = hasSuggestedTexts
        }

        init(
            details: [InAppEventDetail: PendingChange] = [:], dates: PendingChange? = nil, missingArt: [InAppEventMedia.Kind] = [],
            draftedLocales: Set<String> = [], hasSuggestedTexts: Bool = false
        ) {
            self.details = details
            self.dates = dates
            self.missingArt = missingArt
            self.draftedLocales = draftedLocales
            self.hasSuggestedTexts = hasSuggestedTexts
        }
    }

    /// The event's list at `now`, with what `waiting` fills, and `claim`:
    /// whether the app claims the deep link it will have. The dates' items
    /// say what's wrong with the dates it will have (`InAppEventDateRule`).
    static func items(
        for event: InAppEvent, waiting: Waiting, claim: InAppEventLinkClaim, appName: String, now: Date, format: InAppEventDateText = .current
    ) -> [Self] {
        let needs = event.reviewNeeds(now: now)
        var items: [Self] = []
        var datesIndex: Int?
        for need in needs {
            if need.dateField != nil {
                if datesIndex == nil { datesIndex = items.count }
                continue
            }
            items.append(Self(
                kind: .need(need), state: state(of: need, in: event, waiting: waiting), text: need.title, detail: Self.detail(need, appName: appName)
            ))
        }
        let dates = dateItems(for: event, needs: needs.filter { $0.dateField != nil }, waiting: waiting, now: now, format: format)
        if !dates.isEmpty {
            let texts: Set<InAppEventReviewNeed> = [.primaryTexts, .languageTexts, .card, .details]
            let index = datesIndex ?? items.firstIndex { $0.need.map(texts.contains) == true } ?? items.endIndex
            items.insert(contentsOf: dates, at: index)
        }
        if case let .notClaimed(what) = claim {
            let item = Self(kind: .linkNotClaimed(what), state: .missing, text: claim.message(appName: appName) ?? "", detail: claim.detail)
            let index = items.firstIndex { $0.need != .deepLink } ?? items.endIndex
            items.insert(item, at: index)
        }
        return items
    }

    /// The event's list from Review & Push alone, outside its page (the
    /// Submit sheet, MCP).
    static func items(
        for event: InAppEvent, changes: [PendingChange], builder: InAppEventChangeBuilder, claim: InAppEventLinkClaim, appName: String,
        now: Date, format: InAppEventDateText = .current
    ) -> [Self] {
        items(for: event, waiting: Waiting(for: event, changes: changes, builder: builder), claim: claim, appName: appName, now: now, format: format)
    }

    /// The dates' items. Without dates waiting, what's wrong with App
    /// Store Connect's. With dates waiting that break no rule, the same
    /// items, filled (`queued`, or `suggested` until accepted); with dates
    /// waiting that break one, what's wrong with those.
    private static func dateItems(
        for event: InAppEvent, needs: [InAppEventReviewNeed], waiting: Waiting, now: Date, format: InAppEventDateText
    ) -> [Self] {
        // Each named with the dates of the schedule that breaks it.
        func live(_ need: InAppEventReviewNeed) -> InAppEventDates? {
            need.dateRule.flatMap { event.dates(breaking: $0, now: now) } ?? event.dates
        }
        guard let change = waiting.dates, let queued = InAppEventChangeBuilder.datesValue(in: change) else {
            return needs.map { dateItem($0, of: event, dates: live($0), state: .missing, now: now, format: format) }
        }
        let broken = queued.broken(now: now)
        guard broken.isEmpty else {
            return broken.map { dateItem(InAppEventReviewNeed($0), of: event, dates: queued, state: .missing, now: now, format: format) }
        }
        // An assistant's dates waiting beside the person's need their
        // decision before a push sends either.
        let state: State = change.awaitingAcceptance == nil && change.alternative == nil ? .queued : .suggested
        return needs.map { dateItem($0, of: event, dates: live($0), state: state, now: now, format: format) }
    }

    /// A dates item: what's wrong with `dates` and how to fix it, with the
    /// "Shows from" that does when the card's date is the one to change.
    private static func dateItem(
        _ need: InAppEventReviewNeed, of event: InAppEvent, dates: InAppEventDates?, state: State, now: Date, format: InAppEventDateText
    ) -> Self {
        guard let rule = need.dateRule, let dates else {
            let canEdit = InAppEventChangeBuilder.datesEditProblem(of: event) == nil
            let detail = canEdit
                ? String(localized: "Set them under Details.")
                : String(localized: "Set them in App Store Connect: Atlas can’t change this event’s dates.")
            return Self(kind: .need(need), state: state, text: need.title, detail: detail)
        }
        let suggestion = rule.field == .publishStart ? dates.suggestedPublishStart(now: now, calendar: format.calendar) : nil
        var item = Self(kind: .need(need), state: state, text: rule.text(dates, format), detail: rule.fix(suggestion: suggestion, format))
        if let suggestion { item.suggestedDates = [.publishStart: suggestion] }
        return item
    }

    /// Whether what waits fills `need`.
    private static func state(of need: InAppEventReviewNeed, in event: InAppEvent, waiting: Waiting) -> State {
        let primary = event.primaryLocalization?.locale ?? event.primaryLocale
        let texts: State = waiting.hasSuggestedTexts ? .suggested : .missing
        switch need {
        case .deepLink, .primaryLocale, .purpose:
            guard let detail = need.detail, let change = waiting.details[detail], InAppEventChangeBuilder.detailValue(in: change)?.value != nil
            else { return .missing }
            return change.awaitingAcceptance == nil ? .queued : .suggested
        case .card, .details:
            return waiting.missingArt.contains(need == .card ? .card : .details) ? .missing : .queued
        case .primaryTexts:
            guard let primary, waiting.draftedLocales.contains(primary) else { return texts }
            return .queued
        case .languageTexts:
            let incomplete = event.localizations.filter { $0.locale != primary && !$0.isComplete }.map(\.locale)
            return incomplete.allSatisfy(waiting.draftedLocales.contains) ? .queued : texts
        case .dates, .eventEndBeforeStart, .eventTooShort, .eventTooLong, .publishStartAfterEventStart, .publishStartTooEarly, .eventStartPassed,
             .publishStartPassed:
            // `dateItems` says.
            return .missing
        }
    }

    /// How to fix it, where Atlas can't.
    private static func detail(_ need: InAppEventReviewNeed, appName: String) -> String? {
        switch need {
        case .deepLink: InAppEventDeepLink.example(appName: appName)
        case .primaryLocale, .purpose, .primaryTexts, .languageTexts, .card, .details, .dates, .eventEndBeforeStart, .eventTooShort, .eventTooLong,
             .publishStartAfterEventStart, .publishStartTooEarly, .eventStartPassed, .publishStartPassed:
            nil
        }
    }
}
