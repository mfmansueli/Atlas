//
//  StorePreviewDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The App Store preview on Overview and Store Page (README-Redesign, “On
/// the App Store preview”), Lumen Journal's in English (U.S.), with the
/// Oct 12 sets drawn (`-AtlasDebugScene <id>`):
///
/// - `ov-event`: Overview; the App Preview (0:24) and five screenshots,
///   then Mood Calendar happening now (published, today to two weeks
///   from now).
/// - `sp-event`: the Store Page editor with the same preview beside it.
/// - `ov-event-upcoming`: Overview; Mood Calendar published, its card up
///   since today and starting in three days: "Upcoming".
/// - `ov-preview`: Overview; the App Preview and five screenshots, no
///   event live (Mood Calendar is still a draft): no card.
/// - `sp-preview-noapp`: the Store Page editor; screenshots only, no App
///   Preview, no event.
/// - `sp-preview-suggested`: the Store Page editor in German on Suggested:
///   Claude Code's three shorter captions drawn on screenshots 2, 3 and 5,
///   in purple rings.
enum StorePreviewDebugScenes {
    static let ids = ["ov-event", "sp-event", "ov-event-upcoming", "ov-preview", "sp-preview-noapp", "sp-preview-suggested"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "ov-event": scene(section: .overview, events: liveEvents)
        case "sp-event": scene(section: .storePage, events: liveEvents)
        case "ov-event-upcoming": scene(section: .overview, events: [DebugInAppEventsData.winter, upcomingMood])
        case "ov-preview": scene(section: .overview, events: DebugInAppEventsData.events)
        case "sp-preview-noapp": scene(section: .storePage, events: DebugInAppEventsData.events, hidesAppPreviews: true)
        case "sp-preview-suggested": scene(section: .storePage, events: DebugInAppEventsData.events, locale: .german)
        default: nil
        }
    }

    /// Mood Calendar approved and published, running from the start of
    /// today for two weeks, so the scene shows it whatever the date.
    static var liveMood: InAppEvent {
        var mood = DebugInAppEventsData.mood
        mood.state = .published
        let start = Calendar.gmtGregorian.startOfDay(for: .now)
        mood.schedules[0].publishStart = start
        mood.schedules[0].eventStart = start
        mood.schedules[0].eventEnd = Calendar.gmtGregorian.date(byAdding: .day, value: 14, to: start)
        return mood
    }

    /// Mood Calendar published, its card showing from the start of today,
    /// the event from three days later for two weeks.
    static var upcomingMood: InAppEvent {
        var mood = liveMood
        let shows = Calendar.gmtGregorian.startOfDay(for: .now)
        let start = Calendar.gmtGregorian.date(byAdding: .day, value: 3, to: shows)
        mood.schedules[0].publishStart = shows
        mood.schedules[0].eventStart = start
        mood.schedules[0].eventEnd = start.flatMap { Calendar.gmtGregorian.date(byAdding: .day, value: 14, to: $0) }
        return mood
    }

    static var liveEvents: [InAppEvent] {
        [DebugInAppEventsData.winter, liveMood, DebugInAppEventsData.gratitude]
    }

    @MainActor
    private static func scene(
        section: AppWorkspaceSection, events: [InAppEvent], hidesAppPreviews: Bool = false, locale: StoreLocale = .englishUS
    ) -> AnyView {
        let screenshots = DebugScreenshotsServices()
        screenshots.drawsPushedLiveSets = true
        screenshots.hidesAppPreviews = hidesAppPreviews
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        if section == .storePage {
            storePage.opening = DebugStorePageServices.Opening { $0.openEditor(locale) }
        }
        var services = WorkspaceServices.debug
        services.storePage = storePage
        services.inAppEvents = DebugInAppEventsServices(events: events)
        // As if In-App Events had been read ahead: the preview shows what
        // Atlas last read.
        let store = DebugInAppEventsData.store()
        store.noteRead(events, for: DebugFixtures.AppID.lumen)
        return AnyView(DebugMainScene(services: services, section: section, events: store))
    }
}
#endif
