//
//  InAppEventsSuggestionDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of an assistant's suggestions beside what's there
/// (`-AtlasDebugScene <id>`), on "7 Days of Gratitude" with the clock at
/// Nov 16, 12:00 GMT:
///
/// - `ev-dates-suggested`: the person queued "Shows from Nov 18, 12:00";
///   Claude Code suggests moving the event to Nov 23 – Nov 29, keeping
///   that card date. Details shows both, Yours and Suggested, with
///   Dismiss and Accept; Review & Push asks which one to push.
/// - `ev-text-revision`: English is written and says "…by Sunday";
///   Claude Code suggests a revision of its long description, "…by
///   November 26.", shown as Now and Suggested with the changed words
///   marked, with Dismiss, Use and Edit and Accept.
enum InAppEventsSuggestionDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugInAppEventsData
    typealias Dates = InAppEventsDatesDebugScenes

    static let ids = ["ev-dates-suggested", "ev-text-revision"]

    static let client = "Claude Code"

    /// The person's "Shows from" (Nov 18, 12:00), with Claude Code's dates
    /// for the event waiting beside it.
    @MainActor
    static func datesBesideThePersons() -> [PendingChange] {
        let event = Dates.sevenDays
        guard var persons = Dates.queuedFix().first,
              let theirs = InAppEventChangeBuilder.datesValue(in: persons) else { return [] }
        var suggested = theirs
        suggested.eventStart = Data.date(month: 11, day: 23, hour: 0)
        suggested.eventEnd = Data.date(month: 11, day: 29, hour: 23)
        persons.alternative = InAppEventChangeBuilder(appID: AppIDs.lumen).datesAlternative(
            to: suggested, of: event, now: DebugReviewsData.today, source: .assistant(client: client),
            reason: "Start on a Monday, when most people open Lumen, and end on the Sunday after."
        )
        return [persons]
    }

    /// The streak's English text, written: it ends "by Sunday".
    static var sundayEvent: InAppEvent {
        var event = Dates.sevenDays
        event.localizations = event.localizations.map { localization in
            var localization = localization
            if localization.locale == "en-US" {
                localization.longDescription = "Write one thank-you each evening and reach the 7-day streak milestone by Sunday."
            }
            return localization
        }
        return event
    }

    /// Claude Code's revision of the English long description.
    static let revision = InAppEventTextSuggestion(
        eventID: Dates.gratitudeID, locale: "en-US", name: "", shortDescription: "",
        longDescription: "Write one thank-you each evening and reach the 7-day streak milestone by November 26.",
        why: "The event now ends on Wednesday, November 26, so “by Sunday” is wrong.", source: client, date: DebugReviewsData.today,
        revisedFields: [.longDescription]
    )

    @MainActor
    static func view(for id: String) -> AnyView? {
        let seven = InAppEventsDebugLaunch(eventID: Dates.gratitudeID, locale: "en-US")
        switch id {
        case "ev-dates-suggested":
            return scene(seven, events: [Dates.sevenDays, Data.winter, Data.gratitude], pendingChanges: datesBesideThePersons())
        case "ev-text-revision":
            return scene(seven, events: [sundayEvent, Data.winter, Data.gratitude], suggestions: Data.suggestions + [revision])
        default:
            return nil
        }
    }

    @MainActor
    private static func scene(
        _ launch: InAppEventsDebugLaunch, events: [InAppEvent], pendingChanges: [PendingChange] = [],
        suggestions: [InAppEventTextSuggestion] = Data.suggestions
    ) -> AnyView {
        ProjectLinkClaimsCenter.shared.pin(InAppEventsDeepLinkDebugScenes.claims(declaresScheme: true), for: AppIDs.lumen)
        var services = WorkspaceServices.debug
        services.inAppEvents = DebugInAppEventsServices(events: events)
        InAppEventsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .inAppEvents, pendingChanges: pendingChanges,
            events: Data.store(suggestions: suggestions)
        ))
    }
}
#endif
