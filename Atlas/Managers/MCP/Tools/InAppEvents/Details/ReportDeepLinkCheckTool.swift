//
//  ReportDeepLinkCheckTool.swift
//  Atlas
//

import Foundation

/// `report_deep_link_check`: what an assistant found when it checked in
/// the app's code (and in Simulator, when it could) that the app opens an
/// event's deep link. Kept per event for that deep link: the event's page
/// shows it under the deep link ("Opens the event · checked by Claude Code
/// in build 1.2.0 (21), tried in Simulator"), and the Submit sheet warns
/// when the build going to App Review is older than the one checked. It
/// keeps the dates it was made under: once the event's start or end moves,
/// it's marked stale ("Checked before the dates changed").
struct ReportDeepLinkCheckTool: MCPTool {
    var store = InAppEventsStore.shared
    var now: @Sendable () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "report_deep_link_check",
        title: "Report whether the app opens an event's deep link",
        description: """
        After checking in the app's project that it opens an In-App Event's deep link, tell Atlas what you found: \
        deepLink (the link you checked: the event's, or the one you propose with propose_event_details), opens (true \
        only when it opens this event's screen), shows (what the person sees), beforeStart (what it shows before the \
        event begins: App Review taps Open then, so it must show the event and its start date, never a plain screen), \
        needsPremium (the screen needs a subscription: an event with NO_COST_ASSOCIATED must never land on a paywall), \
        where (file:line where the link is handled), build (MARKETING_VERSION (CURRENT_PROJECT_VERSION) you checked, \
        e.g. "1.2.0 (21)"), testedInSimulator (you opened it with xcrun simctl openurl) and problems (each thing still \
        wrong: cold launch, already open, after onboarding, unknown or ended event). Each report replaces the last for \
        that event; one for another deep link than the event's shows once the event has it. Atlas keeps the dates it \
        was made under (yours when you suggested dates beside the person's, else the event's, queued or App Store \
        Connect's): once its start or end moves, get_in_app_events' deepLinkCheck says `stale: true` with why, as \
        beforeStart may name the old start. Check again and report it.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "deepLink": MCPToolDefinition.string("The deep link checked."),
                "opens": ["type": "boolean", "description": "True only when the link opens this event's screen."],
                "shows": MCPToolDefinition.string("What the person sees when it opens, in one sentence."),
                "beforeStart": MCPToolDefinition.string("What it shows before the event begins."),
                "needsPremium": ["type": "boolean", "description": "The screen it opens needs a subscription."],
                "where": MCPToolDefinition.string("file:line where the link is handled."),
                "build": MCPToolDefinition.string("MARKETING_VERSION (CURRENT_PROJECT_VERSION) checked, e.g. 1.2.0 (21)."),
                "testedInSimulator": ["type": "boolean", "description": "You opened it in a simulator with xcrun simctl openurl."],
                "problems": ["type": "array", "items": ["type": "string"], "description": "Each thing still wrong; empty when none."],
            ],
            required: ["appId", "eventId", "deepLink", "opens", "shows", "build", "testedInSimulator"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let event = try await RenderEventArtworkTool.event(arguments.string("eventId"), of: app, in: context)
        let target = "\(app.name) · \(event.referenceName) · deep link"
        let deepLink = try arguments.string("deepLink")
        if let problem = InAppEventDeepLink.problem(deepLink, appName: app.name) {
            return .refused(String(localized: "deepLink: \(problem)"), target: target)
        }
        guard let opens = try arguments.optionalBool("opens") else {
            throw MCPToolError.invalidArgument(name: "opens", expected: String(localized: "true or false"))
        }
        let build = try arguments.string("build")
        guard InAppEventDeepLinkReport.buildNumber(of: build) != nil else {
            return .refused(String(localized: "build: give the version and build number checked, like 1.2.0 (21)."), target: target)
        }
        let builder = InAppEventChangeBuilder(appID: app.id)
        let changes = context.workspace.changes.changes(for: app.id, section: .inAppEvents)
        let report = try InAppEventDeepLinkReport(
            eventID: event.id, deepLink: deepLink, opens: opens, shows: arguments.string("shows"),
            beforeStart: arguments.optionalString("beforeStart") ?? "", needsPremium: arguments.optionalBool("needsPremium") ?? false,
            location: arguments.optionalString("where") ?? "", build: build,
            testedInSimulator: arguments.optionalBool("testedInSimulator") ?? false,
            problems: arguments.optionalStrings("problems") ?? [], client: context.clientName, date: now(),
            checkedDates: Self.checkedDates(of: event, builder: builder, changes: changes, source: context.source)
        )
        store.setDeepLinkReport(report, for: app.id)
        let current = GetInAppEventsTool.deepLink(of: event, builder: builder, changes: changes)
        var result: [String: JSONValue] = ["status": "saved", "shows": .string(report.statusLine)]
        if !report.isFor(current) {
            result["note"] = .string(current == nil
                ? String(localized: "The event has no deep link yet: propose this one with propose_event_details, and the check shows with it.")
                : String(localized: "The event’s deep link is \(current ?? ""), not this one: the check shows once it has this one (propose it with propose_event_details)."))
        }
        let isFree = (event.purchaseRequirement ?? .noCostAssociated) == .noCostAssociated
        if opens, isFree, report.needsPremium {
            result["warning"] = """
            The event costs nothing (NO_COST_ASSOCIATED) but its link lands on Premium: App Review rejects that. Fix it, \
            then report again.
            """
        }
        if opens, report.beforeStart.isEmpty {
            result["warning"] = "Say what it shows before the event starts (beforeStart): App Review taps Open before then."
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// The dates the check is made under: the ones this assistant suggests
    /// beside the person's (it checked with those in mind), else the ones
    /// the event will have, queued or App Store Connect's. If they move,
    /// the check is marked stale.
    static func checkedDates(
        of event: InAppEvent, builder: InAppEventChangeBuilder, changes: [PendingChange], source: ChangeSource
    ) -> InAppEventDates? {
        if let suggested = builder.suggestedDates(for: event.id, in: changes), suggested.alternative.source == source { return suggested.dates }
        return builder.dates(of: event, in: changes)
    }
}
