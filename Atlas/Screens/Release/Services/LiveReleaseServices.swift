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
            status.submission = try await submission(versionID: version.id, platform: version.platform, appID: app.id)
        }
        if status.phase == .prepare || status.phase == .rejected {
            status.productsToSubmit = await productsToSubmit(appID: app.id)
        }
        return status
    }

    /// Sends each ticked product to App Review, except one an earlier try
    /// already sent.
    private func submitProducts(_ products: [SubmissionProduct], submissionID: String, hasVersion: Bool, eventIDs: [String]) async throws {
        for product in products {
            try await SubmissionFailure.at(.addProduct(product.id), submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs) {
                if let state = try? await client.reviewState(of: product), state != SubmissionProduct.readyToSubmit { return }
                try await client.submitForReview(product)
            }
        }
    }

    /// The subscriptions and in-app purchases Ready to Submit; none when
    /// they can't be read (the sheet still submits the version).
    private func productsToSubmit(appID: String) async -> [SubmissionProduct] {
        let groups = try? await client.pricedSubscriptionGroups(appID: appID)
        let purchases = await (try? client.pricedInAppPurchases(appID: appID)) ?? []
        return Self.productsToSubmit(groups: groups ?? PricingAPIDocument(data: []), purchases: purchases)
    }

    static func productsToSubmit(
        groups: PricingAPIDocument<SubscriptionGroupAttributes>, purchases: [PricingAPIResource<InAppPurchaseAttributes>]
    ) -> [SubmissionProduct] {
        let included = groups.includedByKey()
        let subscriptions = groups.data.flatMap { group in
            group.relatedAll("subscriptions").compactMap { identifier -> SubmissionProduct.Candidate? in
                guard let attributes = included[identifier]?.attributes else { return nil }
                let productID = attributes.productId ?? identifier.id
                return SubmissionProduct.Candidate(id: identifier.id, productID: productID, name: attributes.name ?? productID, state: attributes.state)
            }
        }
        let inAppPurchases = purchases.map { purchase in
            SubmissionProduct.Candidate(
                id: purchase.id, productID: purchase.attributes.productId, name: purchase.attributes.name, state: purchase.attributes.state
            )
        }
        return SubmissionProduct.ready(subscriptions: subscriptions, inAppPurchases: inAppPurchases)
    }

    /// The version's builds, as the Submit sheet reads them, and the one
    /// attached to it.
    func builds(for app: StoreApp, versionID: String, versionString: String, platform: String?) async throws -> ReleaseVersionBuilds {
        let builds = try await client.builds(appID: app.id, versionString: versionString, platform: platform).map(Self.build)
        let attached = try await client.versionBuild(versionID: versionID)
        return ReleaseVersionBuilds(builds: builds, attachedBuildID: attached?.id, attachedBuildNumber: attached?.attributes.version)
    }

    /// The submission the version is in; else one made and never sent.
    private func submission(versionID: String, platform: String?, appID: String) async throws -> VersionSubmission? {
        let submissions = try await client.openReviewSubmissions(appID: appID, platform: platform).map { resource in
            VersionSubmission(
                id: resource.id, state: resource.attributes.state ?? "", submitted: AppStoreConnectDate.date(resource.attributes.submittedDate),
                versionID: resource.relationshipID("appStoreVersionForReview")
            )
        }
        guard var found = submissions.first(where: { $0.versionID == versionID }) ?? submissions.first(where: { $0.isOpen && $0.versionID == nil }) else {
            return nil
        }
        let items = await (try? client.reviewSubmissionEventItems(submissionID: found.id)) ?? []
        found.eventIDs = items.map(\.eventID)
        found.eventItemIDs = Dictionary(items.map { ($0.eventID, $0.itemID) }) { first, _ in first }
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

    /// What it creates (the phased release, the review submission) is read
    /// again first: an attempt that stopped halfway may have made it, and
    /// SimProps's second Submit was refused with "A phasedRelease already
    /// exist under this AppStoreVersion" because the plan still said none.
    ///
    /// A rejected version's submission (unresolved issues) still carries
    /// the version, so it's sent again, as App Store Connect's "Resubmit to
    /// App Review" does. Before, a new submission was made and the version
    /// left out of it because the rejected one had it, and App Store
    /// Connect refused the empty one: "must have an approved
    /// appStoreVersions … or an appStoreVersions must be included".
    ///
    /// Each step that App Store Connect refuses throws a `SubmissionFailure`
    /// naming it and the draft left behind. A draft reused from an earlier
    /// try loses the events no longer ticked, so the person's untick
    /// really takes an event out (Alba 1.2.0: three events without a deep
    /// link made App Store Connect refuse the whole submission).
    func submit(_ plan: SubmissionPlan) async throws {
        typealias Failure = SubmissionFailure
        if plan.buildID != plan.attachedBuildID {
            try await Failure.at(.attachBuild) { try await client.attachBuild(plan.buildID, toVersion: plan.versionID) }
        }
        if let uses = plan.usesNonExemptEncryption {
            try await Failure.at(.encryption) { try await client.setUsesNonExemptEncryption(uses, buildID: plan.buildID) }
        }
        try await Failure.at(.release) { try await client.setRelease(plan.timing, versionID: plan.versionID) }
        try await Failure.at(.phasedRelease) {
            let phasedID = try await client.phasedRelease(versionID: plan.versionID)?.id
            if plan.isPhased, phasedID == nil {
                try await client.createPhasedRelease(versionID: plan.versionID)
            } else if !plan.isPhased, let phasedID {
                try await client.deletePhasedRelease(id: phasedID)
            }
        }
        // The submission to send: one made and never sent, or the rejected
        // one; else a new one. What's "already in it" is about that one only.
        let found = try await Failure.at(.createSubmission) {
            try await submission(versionID: plan.versionID, platform: plan.platform, appID: plan.appID)
        }
        let reused = found.flatMap { $0.isOpen || $0.hasUnresolvedIssues ? $0 : nil }
        let submissionID = try await Failure.at(.createSubmission) {
            if let reused { return reused.id }
            return try await client.createReviewSubmission(appID: plan.appID, platform: plan.platform)
        }
        var hasVersion = reused?.versionID == plan.versionID
        var eventIDs = reused?.eventIDs ?? []
        if !hasVersion {
            try await Failure.at(.addVersion, submissionID: submissionID, eventIDs: eventIDs) {
                try await client.addReviewSubmissionItem(
                    submissionID: submissionID, relationship: "appStoreVersion", type: "appStoreVersions", id: plan.versionID
                )
            }
            hasVersion = true
        }
        if let reused, reused.isOpen {
            for eventID in reused.eventIDs where !plan.eventIDs.contains(eventID) {
                guard let itemID = reused.eventItemIDs[eventID] else { continue }
                try await Failure.at(.removeEvent(eventID), submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs) {
                    try await client.deleteReviewSubmissionItem(id: itemID)
                }
                eventIDs.removeAll { $0 == eventID }
            }
        }
        for eventID in plan.eventIDs where !eventIDs.contains(eventID) {
            try await Failure.at(.addEvent(eventID), submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs) {
                try await client.addReviewSubmissionItem(submissionID: submissionID, relationship: "appEvent", type: "appEvents", id: eventID)
            }
            eventIDs.append(eventID)
        }
        // Subscriptions and in-app purchases go once the version is in the
        // draft and before it's sent: a first one only reaches App Review
        // with a version. One already submitted by an earlier try isn't
        // sent again.
        try await submitProducts(plan.products, submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs)
        try await Failure.at(.send, submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs) {
            try await client.updateReviewSubmission(id: submissionID, attribute: "submitted")
        }
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
