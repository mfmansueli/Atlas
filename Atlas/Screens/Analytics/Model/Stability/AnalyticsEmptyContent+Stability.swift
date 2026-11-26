//
//  AnalyticsEmptyContent+Stability.swift
//  Atlas
//

import Foundation

extension AnalyticsEmptyContent {
    /// Stability with nothing to show yet (board 92, "an-crash-wait",
    /// "an-crash-new", "an-crash-none"); nil when there is.
    static func stability(_ soFar: CrashesSoFar, appName: String) -> AnalyticsEmptyContent? {
        let availability = soFar.availability
        let organizer = String(localized: "Crash logs with stack traces are in Xcode → Organizer.", comment: "kind:hint · Analytics → Stability")
        switch availability {
        case let .versionTooNew(version, previous, previousRate):
            return AnalyticsEmptyContent(
                availability: availability,
                text: String(
                    localized: """
                    Apple shows crashes for \(version) once at least 5 people who share analytics with developers have used it, usually \
                    within a day or two.
                    """,
                    comment: "kind:description · Analytics → Stability, a version too new"
                ),
                facts: [previousFact(previous, rate: previousRate), waitingFact(version)].compactMap(\.self),
                note: previous.map { previous in
                    String(
                        localized: "Atlas compares \(version) with \(previous) as soon as the first numbers arrive.",
                        comment: "kind:hint · Analytics → Stability, a version too new"
                    )
                },
                action: .openVersion(version)
            )
        case .notEnoughPeople:
            return AnalyticsEmptyContent(
                availability: availability,
                text: notEnoughPeopleText(downloads: soFar.downloads, appName: appName),
                facts: [versionFact(soFar), downloadsFact(soFar.downloads)].compactMap(\.self),
                note: organizer
            )
        case .noCrashes:
            return AnalyticsEmptyContent(
                availability: availability,
                text: String(
                    localized: """
                    Fewer than 5 people who share analytics with developers had \(appName) crash, so Apple reports none. That usually \
                    means very few crashes, or none.
                    """,
                    comment: "kind:description · Analytics → Stability, no crashes reported"
                ),
                facts: [versionFact(soFar), sessionsFact(soFar.recentSessions)].compactMap(\.self),
                note: organizer
            )
        case .available, .noSubscriptionsSold, .noPaidSubscribers, .tooFewSubscribers:
            return nil
        }
    }

    /// "Apple counts crashes only from people who share analytics … Parcel
    /// Pal has 61 downloads so far."
    static func notEnoughPeopleText(downloads: Int, appName: String) -> String {
        let rule = String(
            localized: "Apple counts crashes only from people who share analytics with developers, and shows a number once at least 5 of them have had one.",
            comment: "kind:description · Analytics → Stability, a new app"
        )
        let sofar = downloads == 1
            ? String(localized: "\(appName) has 1 download so far.", comment: "kind:description · Analytics → Stability, a new app")
            : String(localized: "\(appName) has \(AnalyticsText.count(downloads)) downloads so far.", comment: "kind:description · Analytics → Stability, a new app")
        return "\(rule) \(sofar)"
    }

    /// "1.3" · "2.1 crashes per 1,000 sessions".
    private static func previousFact(_ version: String?, rate: Double?) -> AnalyticsEmptyFact? {
        guard let version, let rate else { return nil }
        return AnalyticsEmptyFact(
            label: version,
            value: String(
                localized: "\(AnalyticsText.perThousand(rate)) crashes per 1,000 sessions",
                comment: "kind:label · Analytics empty state fact, the version before's crash rate"
            )
        )
    }

    /// "1.4" · "Waiting for 5 people".
    private static func waitingFact(_ version: String) -> AnalyticsEmptyFact {
        AnalyticsEmptyFact(
            label: version,
            value: String(localized: "Waiting for 5 people", comment: "kind:label · Analytics empty state fact, a version too new")
        )
    }

    /// "Version" · "1.0 · live since Nov 1", or "Live since" · "Nov 1"
    /// without a version in the reports.
    private static func versionFact(_ soFar: CrashesSoFar) -> AnalyticsEmptyFact? {
        let since = soFar.isNewApp ? soFar.firstDay.map { AnalyticsText.day($0.date) } : nil
        switch (soFar.newest, since) {
        case let (version?, since?):
            return AnalyticsEmptyFact(
                label: String(localized: "Version", comment: "kind:label · Analytics empty state fact"),
                value: String(localized: "\(version) · live since \(since)", comment: "kind:label · Analytics empty state fact")
            )
        case let (version?, nil):
            return AnalyticsEmptyFact(label: String(localized: "Version", comment: "kind:label · Analytics empty state fact"), value: version)
        case let (nil, since?):
            return AnalyticsEmptyFact(label: String(localized: "Live since", comment: "kind:label · Analytics empty state fact"), value: since)
        case (nil, nil):
            return nil
        }
    }

    private static func downloadsFact(_ downloads: Int) -> AnalyticsEmptyFact {
        AnalyticsEmptyFact(
            label: String(localized: "Downloads", comment: "kind:label · Analytics empty state fact"),
            value: AnalyticsText.count(downloads)
        )
    }

    /// "Sessions, 28 days" · "8,400"; nil without sessions.
    private static func sessionsFact(_ sessions: Int) -> AnalyticsEmptyFact? {
        guard sessions > 0 else { return nil }
        return AnalyticsEmptyFact(
            label: String(localized: "Sessions, 28 days", comment: "kind:label · Analytics empty state fact"),
            value: AnalyticsText.count(sessions)
        )
    }
}
