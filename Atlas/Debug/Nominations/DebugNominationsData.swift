//
//  DebugNominationsData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Lumen's nominations on board 70, on Nov 24, 2026: a draft on this Mac
/// (Lumen 1.4, starting in 9 days), Winter Journaling Week submitted on
/// Nov 20, the Japan launch archived, and Claude Code's Mood Calendar
/// suggestion.
enum DebugNominationsData {
    static let lumen = DebugFixtures.AppID.lumen
    static let quiet = DebugFixtures.AppID.quiet
    static let client = "Claude Code"

    static let draftID = "local-debug-lumen-14"
    static let winterID = "nom-winter"
    static let japanID = "nom-japan"
    static let proposalID = "proposal-mood"

    /// Board 70's today.
    static let now = day(2026, 11, 24, hour: 12)

    static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        var components = DateComponents(year: year, month: month, day: day, hour: hour)
        components.timeZone = .current
        return Calendar.current.date(from: components) ?? .now
    }

    static let appStorePage = "https://apps.apple.com/app/id\(lumen)"
    static let locales = ["en-US", "en-GB", "de-DE", "fr-FR", "es-MX", "es-ES", "it", "pt-BR", "ja", "ko", "zh-Hans", "nl-NL"]

    // MARK: - Nominations

    static var draft: Nomination {
        Nomination(
            id: draftID,
            content: NominationContent(
                name: "Lumen 1.4: Weekly reflections",
                type: .appEnhancements,
                description: """
                Every Sunday, Lumen 1.4 gathers your week on one calm page: your entries, your moods and one question to end it. \
                Search is faster too, across years of writing.
                """,
                publishStart: day(2026, 12, 3),
                devices: [.iPhone, .iPad],
                locales: locales,
                eventIDs: [DebugInAppEventsData.winterID],
                materials: [appStorePage],
                notes: """
                Weekly reflections is the feature people asked for most in this year’s reviews. Winter Journaling Week starts Dec 15 \
                and is built around it.
                """,
                appIDs: [lumen]
            ),
            createdDate: day(2026, 11, 18),
            createdBy: "Mateus"
        )
    }

    static var winter: Nomination {
        Nomination(
            id: winterID,
            state: .submitted,
            content: NominationContent(
                name: "Winter Journaling Week",
                type: .newContent,
                description: """
                Fifteen evenings, fifteen prompts: Winter Journaling Week is a quiet challenge to write one line a day through the \
                holidays, with a weekly reflection at the end of each week.
                """,
                publishStart: day(2026, 12, 15),
                publishEnd: day(2027, 1, 4),
                devices: [.iPhone, .iPad],
                locales: locales,
                eventIDs: [DebugInAppEventsData.winterID],
                materials: [appStorePage, "https://lumen.app/press/winter-journaling-week"],
                notes: "Our biggest event of the year. Last year’s Gratitude Week brought 312 downloads in one week.",
                appIDs: [lumen]
            ),
            createdDate: day(2026, 11, 12),
            submittedDate: day(2026, 11, 20),
            createdBy: "Mateus",
            submittedBy: "Mateus",
            appNames: [lumen: "Lumen Journal"],
            eventNames: [DebugInAppEventsData.winterID: DebugInAppEventsData.winter.referenceName]
        )
    }

    static var japan: Nomination {
        Nomination(
            id: japanID,
            state: .archived,
            content: NominationContent(
                name: "Lumen launch in Japan",
                type: .appLaunch,
                description: """
                Lumen Journal comes to Japan with a Japanese interface, vertical writing and prompts written for Japanese seasons. \
                Quiet Timer launches with it.
                """,
                publishStart: day(2026, 3, 10),
                publishEnd: day(2026, 3, 31),
                devices: [.iPhone, .iPad],
                locales: ["ja"],
                territories: ["JPN"],
                launchInSelectMarketsFirst: true,
                preOrderEnabled: true,
                materials: [appStorePage],
                appIDs: [lumen, quiet]
            ),
            createdDate: day(2026, 1, 8),
            lastModifiedDate: day(2026, 4, 30),
            submittedDate: day(2026, 1, 14),
            createdBy: "Mateus",
            submittedBy: "Mateus",
            appNames: [lumen: "Lumen Journal", quiet: "Quiet Timer"]
        )
    }

    /// What App Store Connect has: submitted and archived.
    static var remote: [Nomination] { [winter, japan] }

    static var proposal: NominationProposal {
        NominationProposal(
            id: proposalID,
            content: NominationContent(
                name: "Lumen 2.0: Mood Calendar",
                type: .appEnhancements,
                description: """
                Lumen 2.0 adds Mood Calendar: a month of moods at a glance, drawn from what you write. Tap a day to read that entry. \
                The Mood Calendar event starts Feb 2 with a two-week challenge.
                """,
                publishStart: day(2027, 2, 2),
                publishEnd: day(2027, 2, 16),
                devices: [.iPhone, .iPad],
                locales: locales,
                eventIDs: [DebugInAppEventsData.moodID],
                materials: [appStorePage],
                notes: "Mood Calendar is Lumen 2.0’s main feature. The event runs for two weeks from Feb 2.",
                appIDs: [lumen]
            ),
            evidence: AssistantEvidence(
                client: client,
                summary: "Lumen 2.0: Mood Calendar · App Enhancements",
                why: "Mood Calendar, an In-App Event, starts Feb 2: about 10 weeks ahead, as Apple suggests.",
                evidence: [],
                layers: SuggestionLayers(details: "The Mood Calendar event and version 2.0 both start Feb 2.", confidence: .fairlySure)
            ),
            receivedAt: now
        )
    }

    /// Lumen's archive on this Mac: the draft, and what a scene adds.
    static func archive(proposal: Bool = false) -> NominationsArchive {
        NominationsArchive(drafts: [draft], proposals: proposal ? [self.proposal] : [])
    }

    // MARK: - Context

    static var context: NominationContext {
        NominationContext(
            apps: DebugFixtures.apps.filter { [lumen, quiet, DebugFixtures.AppID.tempo].contains($0.id) },
            teamName: "Northpier Studio",
            locales: locales,
            version: NominationContext.Version(
                versionString: "1.4",
                isFirstVersion: false,
                whatsNew: """
                • Weekly reflections: each Sunday, one calm page with your week’s entries, moods and a question to close it.
                • Search is now faster across years of writing.
                """
            ),
            events: DebugInAppEventsData.events.map(NominationContextReader.event),
            links: [
                NominationContext.appStoreLink(for: DebugFixtures.lumen),
                NominationContext.KnownLink(
                    title: "Custom product page · Prompts", detail: "Approved · 12 languages", url: "\(appStorePage)?ppid=7c1e04b2-prompts"
                ),
                NominationContext.KnownLink(
                    title: "Custom product page · Mood tracking", detail: "Approved · 6 languages", url: "\(appStorePage)?ppid=2d9a71f0-mood"
                ),
            ]
        )
    }

    /// Apple's 422 for a link in the description.
    static let refusal = NominationRefusal(
        kind: "create",
        details: "422 · ENTITY_ERROR.ATTRIBUTE.INVALID — POST /v1/nominations. Apple: “The description must not contain URLs.”",
        date: day(2026, 11, 24, hour: 14)
    )
}
#endif
