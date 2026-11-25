//
//  GetReleaseTool.swift
//  Atlas
//

import Foundation

/// `get_release`: per platform, the version the Overview's version card
/// follows, as the card and the Submit sheet read it, the actions
/// possible now, and the release actions assistants proposed.
struct GetReleaseTool: MCPTool {
    var proposals = ReleaseProposalStore.shared
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "get_release",
        title: "Read the release",
        description: """
        Returns, per platform, the version on its way to the App Store (being prepared, with App Review, approved or \
        rolling out; else the one live): its state and phase (prepare, waiting, review, rejected, pending = approved \
        and waiting for the person, approved = Apple releases it, phased, live), releaseType (MANUAL, AFTER_APPROVAL, \
        SCHEDULED with earliestReleaseDate), phasedRelease (state ACTIVE/PAUSED/COMPLETE, day of 7, percentage of \
        automatic updates), the review submission (state, submittedDate, items: the version and the In-App Events in \
        it), attachedBuild, and possibleActions now. Before submitting (and after a rejection) also builds (newest \
        first; only VALID ones that haven't expired can be chosen), defaultBuildId, whatsNew per language (missing, \
        suggested, notPushed), encryption (the answer known for the default build, null when none), \
        reviewInformationComplete, pendingChanges in Review & Push (they're pushed with the submission), \
        offeredEvents that could go with it, productsToSubmit (subscriptions and in-app purchases Ready to Submit, \
        which Submit sends with the version; firstOfItsKind ones only reach App Review with a version), and \
        submitBlockers. A rejected version has rejection: App Review's message isn't in the API, so ask the person. \
        `proposals` lists the release actions proposed for the app (pending, outdated with whyOutdated, confirmed, \
        dismissed, withdrawn, replaced). Propose one with propose_release_action.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "platform": MCPToolDefinition.string("IOS, MAC_OS, VISION_OS or TV_OS; every platform when left out."),
            ],
            required: ["appId"]
        ),
        proposalKind: nil
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let release = try await MCPRelease.load(app, platform: MCPRelease.platform(arguments), in: context)
        var platforms: [JSONValue] = []
        for status in release.statuses {
            let isBeforeSubmitting = status.phase == .prepare || status.phase == .rejected
            var readiness: MCPReleaseReadiness?
            if isBeforeSubmitting { readiness = await MCPReleaseReadiness.load(for: status, app: app, in: context, now: now()) }
            var number: String?
            if !isBeforeSubmitting, status.attachedBuild == nil, status.attachedBuildID != nil {
                let builds = try? await context.workspace.services.release.builds(
                    for: app, versionID: status.version.id, versionString: status.version.versionString, platform: status.version.platform
                )
                number = builds?.attachedBuildNumber
            }
            var names: [String: String] = [:]
            if let submission = status.submission, !submission.eventIDs.isEmpty {
                // Events in a sent submission aren't offered anymore: all of them.
                let events = await (try? context.workspace.services.inAppEvents.events(for: app)) ?? []
                for event in events { names[event.id] = ReleaseViewModel.displayName(of: event) }
            }
            platforms.append(MCPReleaseJSON.json(status, app: app, readiness: readiness, attachedBuildNumber: number, eventNames: names))
        }
        let proposed = proposals.proposals(for: app.id).map { MCPReleaseJSON.json($0, problem: MCPReleaseJSON.problem(of: $0, in: release)) }
        let result: JSONValue = [
            "app": ["appId": .string(app.id), "name": .string(app.name)],
            "platforms": .array(platforms),
            "proposals": .array(proposed),
            "note": """
            Submitting, releasing and every other action are the person's: propose one with propose_release_action and it \
            waits on the Overview's version card until they confirm it.
            """,
        ]
        return .read(result, target: String(localized: "\(app.name) · Release"))
    }
}
