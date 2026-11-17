//
//  LiveReleaseServices.swift
//  Atlas
//

import Foundation

/// The real `ReleaseServices`, backed by App Store Connect. Each write is
/// one request, in the order App Store Connect needs them; the first one
/// it refuses stops the rest and is what the sheet shows.
@MainActor
struct LiveReleaseServices: ReleaseServices {
    let client: AppStoreConnectClient

    // MARK: - Reading

    func status(for app: StoreApp, platform: String?) async throws -> ReleaseStatus? {
        let versions = try await client.appStoreVersionReleases(appID: app.id)
        guard let resource = Self.followed(versions, platform: platform) else { return nil }
        let attributes = resource.attributes
        let version = ReleaseVersion(
            id: resource.id, versionString: attributes.versionString, platform: attributes.platform, state: attributes.state ?? "",
            timing: ReleaseTiming(releaseType: attributes.releaseType, earliestReleaseDate: AppStoreConnectDate.date(attributes.earliestReleaseDate))
        )
        var status = ReleaseStatus(version: version)
        status.phased = try await client.phasedRelease(versionID: version.id).map(Self.phased)
        status.attachedBuildID = try await client.versionBuild(versionID: version.id)?.id
        if status.phase == .prepare || status.phase == .rejected {
            status.builds = try await client.builds(appID: app.id, versionString: version.versionString, platform: version.platform).map(Self.build)
            let detail = try await client.appStoreReviewDetail(versionID: version.id)
            status.isReviewInformationComplete = detail.map { AppInformationContentLoader.review($0.attributes).isComplete } ?? false
        }
        if status.phase != .live {
            status.submission = try await submission(for: version, appID: app.id)
        }
        return status
    }

    /// The submission the version is in; else one made and never sent.
    private func submission(for version: ReleaseVersion, appID: String) async throws -> VersionSubmission? {
        let submissions = try await client.openReviewSubmissions(appID: appID, platform: version.platform).map { resource in
            VersionSubmission(
                id: resource.id, state: resource.attributes.state ?? "", submitted: AppStoreConnectDate.date(resource.attributes.submittedDate),
                versionID: resource.relationshipID("appStoreVersionForReview")
            )
        }
        guard var found = submissions.first(where: { $0.versionID == version.id }) ?? submissions.first(where: { $0.isOpen && $0.versionID == nil }) else {
            return nil
        }
        found.eventIDs = await (try? client.reviewSubmissionEventIDs(submissionID: found.id)) ?? []
        return found
    }

    /// The version to follow: one on its way first, then one being
    /// prepared, then the one on the App Store; of `platform` when the
    /// app has versions for it.
    static func followed(
        _ versions: [AppStoreConnectResource<AppStoreVersionReleaseAttributes>], platform: String?
    ) -> AppStoreConnectResource<AppStoreVersionReleaseAttributes>? {
        let ofPlatform = versions.filter { $0.attributes.platform == platform }
        let candidates = platform == nil || ofPlatform.isEmpty ? versions : ofPlatform
        func rank(_ resource: AppStoreConnectResource<AppStoreVersionReleaseAttributes>) -> Int {
            let phase = ReleasePhase(state: resource.attributes.state ?? "", phased: nil)
            let state = resource.attributes.state ?? ""
            if phase.isInFlight { return 0 }
            if phase == .rejected || phase == .prepare, !Self.retiredStates.contains(state) { return 1 }
            return Self.liveStates.contains(state) ? 2 : 3
        }
        return candidates.min { lhs, rhs in
            let (left, right) = (rank(lhs), rank(rhs))
            return left == right ? (lhs.attributes.createdDate ?? "") > (rhs.attributes.createdDate ?? "") : left < right
        }
    }

    private static let liveStates: Set<String> = ["READY_FOR_DISTRIBUTION", "READY_FOR_SALE"]
    /// Versions that are over: nothing to submit or follow.
    private static let retiredStates: Set<String> = [
        "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE", "DEVELOPER_REMOVED_FROM_SALE", "NOT_APPLICABLE",
    ]

    static func build(_ resource: AppStoreConnectResource<BuildAttributes>) -> ReleaseBuild {
        ReleaseBuild(
            id: resource.id,
            number: resource.attributes.version ?? "",
            uploaded: AppStoreConnectDate.date(resource.attributes.uploadedDate),
            processing: ReleaseBuild.Processing(rawValue: resource.attributes.processingState ?? "") ?? .processing,
            isExpired: resource.attributes.expired ?? false,
            usesNonExemptEncryption: resource.attributes.usesNonExemptEncryption
        )
    }

    static func phased(_ resource: AppInformationResourceDocument<PhasedReleaseAttributes>.Resource) -> PhasedRelease {
        PhasedRelease(
            id: resource.id,
            state: PhasedRelease.State(rawValue: resource.attributes.phasedReleaseState ?? "") ?? .inactive,
            day: resource.attributes.currentDayNumber ?? 0,
            startDate: AppStoreConnectDate.date(resource.attributes.startDate)
        )
    }

    // MARK: - Writing

    func submit(_ plan: SubmissionPlan) async throws {
        if plan.buildID != plan.attachedBuildID {
            try await client.attachBuild(plan.buildID, toVersion: plan.versionID)
        }
        if let uses = plan.usesNonExemptEncryption {
            try await client.setUsesNonExemptEncryption(uses, buildID: plan.buildID)
        }
        try await client.setRelease(plan.timing, versionID: plan.versionID)
        if plan.isPhased, plan.phasedReleaseID == nil {
            try await client.createPhasedRelease(versionID: plan.versionID)
        } else if !plan.isPhased, let id = plan.phasedReleaseID {
            try await client.deletePhasedRelease(id: id)
        }
        let submissionID: String = if let open = plan.openSubmission, open.isOpen {
            open.id
        } else {
            try await client.createReviewSubmission(appID: plan.appID, platform: plan.platform)
        }
        if plan.openSubmission?.versionID != plan.versionID {
            try await client.addReviewSubmissionItem(submissionID: submissionID, relationship: "appStoreVersion", type: "appStoreVersions", id: plan.versionID)
        }
        for eventID in plan.eventIDs where plan.openSubmission?.eventIDs.contains(eventID) != true {
            try await client.addReviewSubmissionItem(submissionID: submissionID, relationship: "appEvent", type: "appEvents", id: eventID)
        }
        try await client.updateReviewSubmission(id: submissionID, attribute: "submitted")
    }

    func submitEvents(_ eventIDs: [String], for app: StoreApp, platform: String?) async throws {
        guard !eventIDs.isEmpty else { return }
        let submissionID = try await client.createReviewSubmission(appID: app.id, platform: platform)
        for eventID in eventIDs {
            try await client.addReviewSubmissionItem(submissionID: submissionID, relationship: "appEvent", type: "appEvents", id: eventID)
        }
        try await client.updateReviewSubmission(id: submissionID, attribute: "submitted")
    }

    func cancelSubmission(_ id: VersionSubmission.ID) async throws {
        try await client.updateReviewSubmission(id: id, attribute: "canceled")
    }

    func resubmit(_ id: VersionSubmission.ID) async throws {
        try await client.updateReviewSubmission(id: id, attribute: "submitted")
    }

    func release(versionID: String) async throws {
        try await client.requestRelease(versionID: versionID)
    }

    func setPhasedRelease(_ id: PhasedRelease.ID, to state: PhasedRelease.State) async throws {
        try await client.setPhasedRelease(id: id, state: state)
    }
}
