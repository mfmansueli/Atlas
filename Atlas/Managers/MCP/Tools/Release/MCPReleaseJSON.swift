//
//  MCPReleaseJSON.swift
//  Atlas
//

import Foundation

/// `get_release`'s JSON for one platform's version, and for the release
/// proposals.
@MainActor
enum MCPReleaseJSON {
    /// The version, its review submission (with the In-App Events in it),
    /// App Review's rejection as far as the API tells it, the builds, how
    /// it's released, the phased release, what's ready for Submit (before
    /// submitting) and the actions possible now.
    static func json(
        _ status: ReleaseStatus, app: StoreApp, readiness: MCPReleaseReadiness?, attachedBuildNumber: String?, eventNames: [String: String]
    ) -> JSONValue {
        let version = status.version
        var object: [String: JSONValue] = [
            "platform": version.platform.map(JSONValue.string) ?? .null,
            "title": .string(version.platform.flatMap(StorePageVersion.title(ofPlatform:)) ?? version.platform ?? ""),
            "version": [
                "id": .string(version.id),
                "versionString": .string(version.versionString),
                "state": .string(version.state),
                "phase": .string(status.phase.key),
                "phaseTitle": .string(status.phase.pillTitle),
            ],
            "releaseType": .string(version.timing.releaseType),
            "earliestReleaseDate": version.timing.date.map { .string($0.formatted(.iso8601)) } ?? .null,
            "phasedRelease": status.phased.map(phasedJSON) ?? .null,
            "submission": status.submission.map { submissionJSON($0, eventNames: eventNames) } ?? .null,
            "attachedBuild": attachedJSON(status, number: attachedBuildNumber),
            "possibleActions": .array(ReleaseProposalRules.possibleActions(in: status).map { action in
                ["action": .string(action.rawValue), "title": .string(action.title(version: version.versionString))]
            }),
        ]
        if status.phase == .rejected { object["rejection"] = rejectionJSON(status, app: app) }
        if status.phase == .prepare || status.phase == .rejected {
            object["builds"] = .array(status.builds.map { MCPAppVersions.json($0, attached: $0.id == status.attachedBuildID) })
            object["defaultBuildId"] = ReleaseViewModel.defaultBuildID(in: status).map(JSONValue.string) ?? .null
            object["reviewInformationComplete"] = .bool(status.isReviewInformationComplete)
            if let readiness { object.merge(readinessJSON(readiness, status: status)) { _, new in new } }
        }
        return .object(object)
    }

    /// `{state, day, percentage, startDate}`.
    private static func phasedJSON(_ phased: PhasedRelease) -> JSONValue {
        [
            "id": .string(phased.id),
            "state": .string(phased.state.rawValue),
            "day": .int(phased.day),
            "dayCount": .int(PhasedRelease.dayCount),
            "percentage": phased.day > 0 ? .int(PhasedRelease.percentage(day: phased.day)) : .null,
            "startDate": phased.startDate.map { .string($0.formatted(.iso8601)) } ?? .null,
        ]
    }

    /// `{id, state, submittedDate, items}`: the version and each event.
    private static func submissionJSON(_ submission: VersionSubmission, eventNames: [String: String]) -> JSONValue {
        var items: [JSONValue] = []
        if let versionID = submission.versionID { items.append(["type": "appStoreVersion", "id": .string(versionID)]) }
        items += submission.eventIDs.map { id -> JSONValue in
            ["type": "appEvent", "id": .string(id), "name": eventNames[id].map(JSONValue.string) ?? .null]
        }
        return [
            "id": .string(submission.id),
            "state": .string(submission.state),
            "submittedDate": submission.submitted.map { .string($0.formatted(.iso8601)) } ?? .null,
            "items": .array(items),
        ]
    }

    /// The attached build, with its number even when it isn't among the
    /// builds read.
    private static func attachedJSON(_ status: ReleaseStatus, number: String?) -> JSONValue {
        if let build = status.attachedBuild { return MCPAppVersions.json(build, attached: true) }
        guard let id = status.attachedBuildID else { return .null }
        return ["id": .string(id), "buildNumber": number.map(JSONValue.string) ?? .null, "attached": true]
    }

    /// App Review's message isn't in the App Store Connect API.
    private static func rejectionJSON(_ status: ReleaseStatus, app: StoreApp) -> JSONValue {
        [
            "versionState": .string(status.version.state),
            "submissionState": status.submission.map { .string($0.state) } ?? .null,
            "message": .null,
            "messageNote": """
            App Review's message and the conversation with it aren't in the App Store Connect API: ask the person what it \
            says (they read it in App Store Connect), and propose the fix (texts, the demo account, a new build) before \
            proposing submit or resubmit.
            """,
            "appStoreConnectURL": .string("https://appstoreconnect.apple.com/apps/\(app.id)/distribution"),
            "resubmitsDirectly": .bool(status.submission?.hasUnresolvedIssues == true),
        ]
    }

    /// What's New per language, the events that could go with the version,
    /// the encryption answer, the changes waiting and what still stops
    /// Submit.
    private static func readinessJSON(_ readiness: MCPReleaseReadiness, status: ReleaseStatus) -> [String: JSONValue] {
        let build = ReleaseViewModel.defaultBuildID(in: status).flatMap { id in status.builds.first { $0.id == id } }
        var object: [String: JSONValue] = [
            "whatsNew": readiness.whatsNew.isEmpty
                ? .null
                : [
                    "languages": .int(readiness.whatsNew.count),
                    "ready": .int(readiness.whatsNew.count { !$0.isMissing }),
                    "missing": .array(readiness.missingWhatsNew.map { .string($0.locale.code) }),
                    "suggested": .array(readiness.suggestedWhatsNew.map { .string($0.locale.code) }),
                    "notPushed": .array(readiness.whatsNew.filter { $0.state == .notPushed }.map { .string($0.locale.code) }),
                ],
            "encryption": readiness.encryption(for: build).map { .string($0.rawValue) } ?? .null,
            "pendingChanges": .int(readiness.pendingChanges),
            "offeredEvents": .array(readiness.offeredEvents.map { event in
                [
                    "id": .string(event.id),
                    "name": .string(ReleaseViewModel.displayName(of: event)),
                    "state": .string(event.state.rawValue),
                    "inSubmission": .bool(status.submission?.eventIDs.contains(event.id) == true),
                ]
            }),
            "submitBlockers": .array(readiness.blockers(for: status).map(JSONValue.string)),
        ]
        if let error = readiness.eventsError { object["eventsError"] = .string(error) }
        return object
    }

    /// One proposal: pending ones the version no longer allows are
    /// `outdated`, with why.
    static func json(_ proposal: ReleaseProposal, problem: String?) -> JSONValue {
        var object: [String: JSONValue] = [
            "proposalId": .string(proposal.id),
            "action": .string(proposal.action.rawValue),
            "title": .string(proposal.title),
            "versionString": .string(proposal.versionString),
            "platform": proposal.platform.map(JSONValue.string) ?? .null,
            "client": .string(proposal.client),
            "reason": .string(proposal.evidence.why),
            "status": .string(proposal.isPending && problem != nil ? "outdated" : proposal.status.rawValue),
            "receivedAt": .string(proposal.receivedAt.formatted(.iso8601)),
        ]
        if proposal.isPending, let problem { object["whyOutdated"] = .string(problem) }
        proposal.evidence.layers?.add(to: &object)
        if let resolved = proposal.resolvedAt { object["resolvedAt"] = .string(resolved.formatted(.iso8601)) }
        if let submission = proposal.submission {
            var choices: [String: JSONValue] = [
                "buildId": .string(submission.buildID),
                "buildNumber": .string(submission.buildNumber),
                "releaseType": .string(submission.releaseType),
                "phasedRelease": .bool(submission.isPhased),
            ]
            if let date = submission.releaseDate { choices["releaseDate"] = .string(date.formatted(.iso8601)) }
            if let encryption = submission.encryption { choices["encryption"] = .string(encryption) }
            if let ids = submission.eventIDs { choices["eventIds"] = .array(ids.map(JSONValue.string)) }
            if let pushes = submission.pushesChanges { choices["pushesChanges"] = .bool(pushes) }
            object["submit"] = .object(choices)
        }
        return .object(object)
    }

    /// Why a proposal no longer fits the versions read: another version
    /// now, or an action the state doesn't allow.
    static func problem(of proposal: ReleaseProposal, in release: MCPRelease) -> String? {
        guard proposal.isPending else { return nil }
        guard let status = release.statuses.first(where: { $0.version.id == proposal.versionID }) else {
            return String(localized: "\(proposal.versionString) isn’t the version being prepared or on its way anymore.")
        }
        return ReleaseProposalRules.problem(proposal.action, in: status)
    }
}
