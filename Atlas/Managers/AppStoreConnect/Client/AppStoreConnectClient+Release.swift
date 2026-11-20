//
//  AppStoreConnectClient+Release.swift
//  Atlas
//

import Foundation

/// Submit for Review and release: the version's builds, its phased
/// release and the app's review submissions, and the writes behind Submit,
/// Cancel Submission, Release Now and Pause.
extension AppStoreConnectClient {
    // MARK: - Reading

    /// The builds uploaded for one version of the app, newest first
    /// (`GET /v1/builds?filter[app]=…&filter[preReleaseVersion.version]=…`).
    func builds(appID: String, versionString: String, platform: String?, limit: Int = 10) async throws -> [AppStoreConnectResource<BuildAttributes>] {
        var query = [
            URLQueryItem(name: "filter[app]", value: appID),
            URLQueryItem(name: "filter[preReleaseVersion.version]", value: versionString),
            URLQueryItem(name: "sort", value: "-uploadedDate"),
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,expired,usesNonExemptEncryption"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let platform { query.append(URLQueryItem(name: "filter[preReleaseVersion.platform]", value: platform)) }
        let page: AppStoreConnectPage<BuildAttributes> = try await get(url("/v1/builds", query: query))
        return page.data
    }

    /// The version's phased release; nil when it has none
    /// (`GET /v1/appStoreVersions/{id}/appStoreVersionPhasedRelease`).
    func phasedRelease(versionID: String) async throws -> AppInformationResourceDocument<PhasedReleaseAttributes>.Resource? {
        do {
            let document: AppInformationResourceDocument<PhasedReleaseAttributes> = try await get(
                url("/v1/appStoreVersions/\(versionID)/appStoreVersionPhasedRelease")
            )
            return document.data
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// The app's submissions that aren't finished, each with the version
    /// it's for (`GET /v1/apps/{id}/reviewSubmissions`).
    func openReviewSubmissions(appID: String, platform: String?) async throws -> [AppInformationResourceDocument<ReviewSubmissionAttributes>.Resource] {
        var query = [
            URLQueryItem(name: "filter[state]", value: "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES"),
            URLQueryItem(name: "include", value: "appStoreVersionForReview"),
            URLQueryItem(name: "fields[reviewSubmissions]", value: "platform,submittedDate,state,appStoreVersionForReview"),
            URLQueryItem(name: "fields[appStoreVersions]", value: "versionString"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        if let platform { query.append(URLQueryItem(name: "filter[platform]", value: platform)) }
        let page: AppStoreConnectLinkedPage<ReviewSubmissionAttributes> = try await get(url("/v1/apps/\(appID)/reviewSubmissions", query: query))
        return page.data
    }

    /// The In-App Events in a submission
    /// (`GET /v1/reviewSubmissions/{id}/items?include=appEvent`).
    func reviewSubmissionEventIDs(submissionID: String) async throws -> [String] {
        try await reviewSubmissionEventItems(submissionID: submissionID).map(\.eventID)
    }

    /// The In-App Event items of a submission, with each item's id, to take
    /// one out.
    func reviewSubmissionEventItems(submissionID: String) async throws -> [(itemID: String, eventID: String)] {
        let page: AppStoreConnectLinkedPage<ReviewSubmissionItemAttributes> = try await get(url("/v1/reviewSubmissions/\(submissionID)/items", query: [
            URLQueryItem(name: "include", value: "appEvent"),
            URLQueryItem(name: "fields[reviewSubmissionItems]", value: "state,appEvent"),
            URLQueryItem(name: "fields[appEvents]", value: "referenceName"),
            URLQueryItem(name: "limit", value: "50"),
        ]))
        return page.data.compactMap { item in item.relationshipID("appEvent").map { (itemID: item.id, eventID: $0) } }
    }

    /// Takes an item out of a submission that isn't sent yet
    /// (`DELETE /v1/reviewSubmissionItems/{id}`).
    func deleteReviewSubmissionItem(id: String) async throws {
        _ = try await send(PushRequest(method: .delete, path: "/v1/reviewSubmissionItems/\(id)", body: nil))
    }

    // MARK: - Writing

    /// Attaches a build to the version
    /// (`PATCH /v1/appStoreVersions/{id}/relationships/build`).
    func attachBuild(_ buildID: String, toVersion versionID: String) async throws {
        try await write(.patch, "/v1/appStoreVersions/\(versionID)/relationships/build", ["data": ["type": "builds", "id": buildID]])
    }

    /// Answers the build's encryption question (`PATCH /v1/builds/{id}`).
    func setUsesNonExemptEncryption(_ uses: Bool, buildID: String) async throws {
        try await write(.patch, "/v1/builds/\(buildID)", [
            "data": ["type": "builds", "id": buildID, "attributes": ["usesNonExemptEncryption": uses]],
        ])
    }

    /// How the version is released once approved
    /// (`PATCH /v1/appStoreVersions/{id}`).
    func setRelease(_ timing: ReleaseTiming, versionID: String) async throws {
        let earliest: Any = timing.date.map(AppStoreConnectDate.text) ?? NSNull()
        try await write(.patch, "/v1/appStoreVersions/\(versionID)", [
            "data": [
                "type": "appStoreVersions", "id": versionID,
                "attributes": ["releaseType": timing.releaseType, "earliestReleaseDate": earliest],
            ],
        ])
    }

    /// Turns phased release on for the version; it starts when the
    /// version is released (`POST /v1/appStoreVersionPhasedReleases`).
    func createPhasedRelease(versionID: String) async throws {
        try await write(.post, "/v1/appStoreVersionPhasedReleases", [
            "data": [
                "type": "appStoreVersionPhasedReleases",
                "attributes": ["phasedReleaseState": PhasedRelease.State.inactive.rawValue],
                "relationships": ["appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]],
            ],
        ])
    }

    /// Turns phased release off before the version is released
    /// (`DELETE /v1/appStoreVersionPhasedReleases/{id}`).
    func deletePhasedRelease(id: String) async throws {
        _ = try await send(PushRequest(method: .delete, path: "/v1/appStoreVersionPhasedReleases/\(id)", body: nil))
    }

    /// Pauses, resumes or completes a phased release
    /// (`PATCH /v1/appStoreVersionPhasedReleases/{id}`).
    func setPhasedRelease(id: String, state: PhasedRelease.State) async throws {
        try await write(.patch, "/v1/appStoreVersionPhasedReleases/\(id)", [
            "data": ["type": "appStoreVersionPhasedReleases", "id": id, "attributes": ["phasedReleaseState": state.rawValue]],
        ])
    }

    /// A new, empty submission; returns its id (`POST /v1/reviewSubmissions`).
    func createReviewSubmission(appID: String, platform: String?) async throws -> String {
        var data: [String: Any] = [
            "type": "reviewSubmissions",
            "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
        ]
        if let platform { data["attributes"] = ["platform": platform] }
        let response = try await send(PushRequest(method: .post, path: "/v1/reviewSubmissions", body: JSONSerialization.data(withJSONObject: ["data": data])))
        guard let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let created = object["data"] as? [String: Any], let id = created["id"] as? String
        else { throw AppStoreConnectError.unexpectedPayload }
        return id
    }

    /// Adds a version (`appStoreVersion`, `appStoreVersions`) or an In-App
    /// Event (`appEvent`, `appEvents`) to a submission
    /// (`POST /v1/reviewSubmissionItems`).
    func addReviewSubmissionItem(submissionID: String, relationship: String, type: String, id: String) async throws {
        try await write(.post, "/v1/reviewSubmissionItems", [
            "data": [
                "type": "reviewSubmissionItems",
                "relationships": [
                    "reviewSubmission": ["data": ["type": "reviewSubmissions", "id": submissionID]],
                    relationship: ["data": ["type": type, "id": id]],
                ],
            ],
        ])
    }

    /// Sends a submission to App Review (`submitted`) or takes it back
    /// (`canceled`) (`PATCH /v1/reviewSubmissions/{id}`).
    func updateReviewSubmission(id: String, attribute: String) async throws {
        try await write(.patch, "/v1/reviewSubmissions/\(id)", [
            "data": ["type": "reviewSubmissions", "id": id, "attributes": [attribute: true]],
        ])
    }

    /// Releases an approved version that waits for the developer
    /// (`POST /v1/appStoreVersionReleaseRequests`).
    func requestRelease(versionID: String) async throws {
        try await write(.post, "/v1/appStoreVersionReleaseRequests", [
            "data": [
                "type": "appStoreVersionReleaseRequests",
                "relationships": ["appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]],
            ],
        ])
    }

    private func write(_ method: PushRequest.Method, _ path: String, _ document: [String: Any]) async throws {
        _ = try await send(PushRequest(method: method, path: path, body: JSONSerialization.data(withJSONObject: document)))
    }
}
