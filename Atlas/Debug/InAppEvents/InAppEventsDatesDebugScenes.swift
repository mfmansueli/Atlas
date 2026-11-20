//
//  InAppEventsDatesDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of a draft's dates (`-AtlasDebugScene <id>`), on
/// Lumen Journal's sample events, with the clock at Nov 16, 12:00 GMT:
///
/// - `ev-dates-past`: "7 Days of Gratitude", ready but for its card's
///   date, Nov 16 at 00:00 GMT, which has passed (Alba 1.2.0: "Supplied
///   date must be in the future"). "Before App Review" lists it with Show
///   from Nov 18, 12:00 PM; the Event card's row says it has passed, with
///   Fix…; the footer isn't "Ready".
/// - `ev-dates-queued`: the same, with the new "Shows from" waiting in
///   Review & Push.
/// - `ev-dates-soon`: the Mood Calendar starts in 20 hours: a warning
///   about App Review's time, which doesn't block.
/// - `ev-dates-unknown`: an event read without its territories: the
///   dates show as text, with why Atlas can't change them.
enum InAppEventsDatesDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugInAppEventsData

    static let ids = ["ev-dates-past", "ev-dates-queued", "ev-dates-soon", "ev-dates-unknown"]

    static let gratitudeID = "event-seven-days"

    /// "7 Days of Gratitude": everything App Review needs but a card's
    /// date that has passed.
    static var sevenDays: InAppEvent {
        var event = Data.mood
        event.id = gratitudeID
        event.referenceName = "7 Days of Gratitude"
        event.badge = .challenge
        event.deepLink = "lumen://gratitude"
        event.schedules = [InAppEventSchedule(
            territories: Data.territories, publishStart: Data.date(month: 11, day: 16, hour: 0), eventStart: Data.date(month: 11, day: 20, hour: 0),
            eventEnd: Data.date(month: 11, day: 26, hour: 23)
        )]
        event.localizations = event.localizations.map { localization in
            var localization = localization
            localization.id = localization.id.replacingOccurrences(of: Data.moodID, with: gratitudeID)
            localization.name = "7 Days of Gratitude"
            localization.shortDescription = "A thank-you a day for a week"
            localization.longDescription = "One small thank-you each evening for seven days, with a new prompt every night."
            return localization
        }
        return event
    }

    /// The Mood Calendar starting tomorrow morning, its card from today.
    static var soonMood: InAppEvent {
        var event = Data.mood
        event.schedules = [InAppEventSchedule(
            territories: Data.territories, publishStart: Data.date(month: 11, day: 16, hour: 20), eventStart: Data.date(month: 11, day: 17, hour: 8),
            eventEnd: Data.date(month: 12, day: 8)
        )]
        return event
    }

    /// The new "Shows from" for "7 Days of Gratitude", waiting.
    @MainActor
    static func queuedFix() -> [PendingChange] {
        let event = sevenDays
        guard var dates = event.dates else { return [] }
        dates.publishStart = Data.date(month: 11, day: 18, hour: 12)
        let change = InAppEventChangeBuilder(appID: AppIDs.lumen).datesChange(to: dates, of: event, now: DebugReviewsData.today, source: .you)
        return [change].compactMap(\.self)
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        let seven = InAppEventsDebugLaunch(eventID: gratitudeID, locale: "en-US")
        switch id {
        case "ev-dates-past":
            return scene(seven, events: [sevenDays, Data.winter, Data.gratitude])
        case "ev-dates-queued":
            return scene(seven, events: [sevenDays, Data.winter, Data.gratitude], pendingChanges: queuedFix())
        case "ev-dates-soon":
            return scene(InAppEventsDebugLaunch(eventID: Data.moodID, locale: "en-US"), events: [Data.winter, soonMood, Data.gratitude])
        case "ev-dates-unknown":
            var unknown = sevenDays
            unknown.schedules[0].territories = []
            return scene(seven, events: [unknown, Data.winter, Data.gratitude])
        default:
            return nil
        }
    }

    @MainActor
    private static func scene(_ launch: InAppEventsDebugLaunch, events: [InAppEvent], pendingChanges: [PendingChange] = []) -> AnyView {
        ProjectLinkClaimsCenter.shared.pin(InAppEventsDeepLinkDebugScenes.claims(declaresScheme: true), for: AppIDs.lumen)
        var services = WorkspaceServices.debug
        services.inAppEvents = DebugInAppEventsServices(events: events)
        InAppEventsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .inAppEvents, pendingChanges: pendingChanges, events: Data.store()
        ))
    }
}
#endif
