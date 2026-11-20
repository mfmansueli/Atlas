//
//  InAppEventsViewModel+EventDetails.swift
//  Atlas
//

import Foundation

// The event page's details (deep link, purpose, priority, primary
// language), edited like its texts: each a change in Review & Push.
// And what the event still needs before App Review, with the check of its
// deep link: the links the app's project claims, and what an assistant
// found in its code.
extension InAppEventsViewModel {
    // MARK: - Details

    /// The detail as it will be: what's queued, else App Store Connect's.
    func detailValue(_ detail: InAppEventDetail, of event: InAppEvent) -> String? {
        if let change = queuedDetail(detail, of: event), let queued = InAppEventChangeBuilder.detailValue(in: change) { return queued.value }
        return detail.value(in: event)
    }

    func queuedDetail(_ detail: InAppEventDetail, of event: InAppEvent) -> PendingChange? {
        queue.change(id: builder.detailChangeID(eventID: event.id, detail: detail))
    }

    /// The person changed a detail: queued like any change; back to App
    /// Store Connect's value, the change leaves the queue.
    func setDetail(_ detail: InAppEventDetail, to value: String?, of event: InAppEvent) {
        guard event.state.isEditable else { return }
        let id = builder.detailChangeID(eventID: event.id, detail: detail)
        if let change = builder.detailChange(detail, to: value, of: event, appName: app.name, source: .you) {
            queue.upsert(change)
        } else {
            queue.discard(id: id)
        }
        if detail == .deepLink { store.dropDeepLinkReport(for: app.id, eventID: event.id, unlessFor: deepLink(of: event)) }
    }

    /// Undo on a detail's row: App Store Connect's value again.
    func revertDetail(_ detail: InAppEventDetail, of event: InAppEvent) {
        queue.discard(id: builder.detailChangeID(eventID: event.id, detail: detail))
        if detail == .deepLink { store.dropDeepLinkReport(for: app.id, eventID: event.id, unlessFor: deepLink(of: event)) }
    }

    /// Accept on an assistant's suggested detail: it waits in Review &
    /// Push like the person's own.
    func acceptDetail(_ detail: InAppEventDetail, of event: InAppEvent) {
        queue.accept(id: builder.detailChangeID(eventID: event.id, detail: detail))
    }

    /// Why `text` can't be the deep link; nil when it can.
    func deepLinkProblem(_ text: String) -> String? {
        InAppEventDeepLink.problem(text, appName: app.name)
    }

    /// The deep link the event will have once pushed.
    func deepLink(of event: InAppEvent) -> String? {
        detailValue(.deepLink, of: event)
    }

    // MARK: - Deep link check

    /// Whether the app's project claims the deep link the event will have.
    func linkClaim(of event: InAppEvent) -> InAppEventLinkClaim {
        InAppEventLinkClaim.of(deepLink(of: event), in: linkClaims.state(for: app.id))
    }

    /// What an assistant found in the code, for the deep link the event
    /// will have.
    func deepLinkReport(of event: InAppEvent) -> InAppEventDeepLinkReport? {
        store.deepLinkReport(for: app.id, eventID: event.id, deepLink: deepLink(of: event))
    }

    /// Why the check may be out of date: made before the event's start or
    /// end moved (queued or in App Store Connect). Nil when it isn't.
    func deepLinkReportStaleText(of event: InAppEvent, format: InAppEventDateText = .current) -> String? {
        deepLinkReport(of: event)?.staleText(for: dates(of: event), suggested: suggestedDates(of: event)?.dates, format)
    }

    // MARK: - Before App Review

    /// The "Before App Review" list: empty when App Store Connect would
    /// take the event,
    /// at the view model's clock.
    func reviewItems(of event: InAppEvent, format: InAppEventDateText = .current) -> [InAppEventReviewItem] {
        guard event.state.isEditable else { return [] }
        let changes = queue.changes(for: app.id, section: .inAppEvents)
        // A revision of a written language fills nothing that's missing,
        // nor does a suggestion the page doesn't show.
        let suggestsTexts = languages(of: event).contains { $0.state == .suggested }
        var waiting = InAppEventReviewItem.Waiting(for: event, changes: changes, builder: builder, hasSuggestedTexts: suggestsTexts)
        waiting.missingArt = missingArt(of: event)
        return InAppEventReviewItem.items(for: event, waiting: waiting, claim: linkClaim(of: event), appName: app.name, now: now(), format: format)
    }

    /// The list's warnings: App Review may not approve the event before
    /// its card shows or it starts. They never block.
    func reviewWarnings(of event: InAppEvent, format: InAppEventDateText = .current) -> [InAppEventReviewWarning] {
        InAppEventReviewWarning.warnings(for: event, queued: queuedDates(of: event), now: now(), format: format)
    }

    /// The fix for a language's texts: the language the editor goes to.
    func localeToWrite(for need: InAppEventReviewNeed, of event: InAppEvent) -> String? {
        let primary = event.primaryLocalization?.locale ?? event.primaryLocale
        switch need {
        case .primaryTexts: return primary
        case .languageTexts: return event.localizations.first { $0.locale != primary && !$0.isComplete }?.locale
        case .deepLink, .primaryLocale, .purpose, .dates, .eventEndBeforeStart, .eventTooShort, .eventTooLong, .publishStartAfterEventStart,
             .publishStartTooEarly, .eventStartPassed, .publishStartPassed, .card, .details:
            return nil
        }
    }

    /// A banner's Write It: the editor shows that language.
    func showLanguage(for need: InAppEventReviewNeed, of event: InAppEvent) {
        guard let locale = localeToWrite(for: need, of: event) else { return }
        localeCode = locale
    }
}
