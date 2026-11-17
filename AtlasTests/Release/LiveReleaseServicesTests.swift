//
//  LiveReleaseServicesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Submitting and releasing against App Store Connect: which version is
/// followed, and the requests each action sends, in order.
@MainActor
@Suite("Release · App Store Connect")
struct LiveReleaseServicesTests {
    private static let done = CannedHTTPResponse(statusCode: 200, body: #"{"data":{"type":"x","id":"x"}}"#)
    private static let noContent = CannedHTTPResponse(statusCode: 204, body: "")
    private static let createdSubmission = CannedHTTPResponse(statusCode: 201, body: #"{"data":{"type":"reviewSubmissions","id":"sub1"}}"#)

    private func services(_ transport: FakeHTTPTransport) -> LiveReleaseServices {
        LiveReleaseServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        let object = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        return object?["data"] as? [String: Any] ?? [:]
    }

    private func calls(_ transport: FakeHTTPTransport) -> [String] {
        transport.requests.map { "\($0.httpMethod ?? "") \($0.url?.path() ?? "")" }
    }

    private typealias Version = AppStoreConnectResource<AppStoreVersionReleaseAttributes>

    private func version(_ id: String, _ state: String, platform: String = "IOS", created: String) -> Version {
        AppStoreConnectResource(type: "appStoreVersions", id: id, attributes: AppStoreVersionReleaseAttributes(
            versionString: id, platform: platform, appStoreState: nil, appVersionState: state, createdDate: created, copyright: nil,
            releaseType: nil, earliestReleaseDate: nil
        ))
    }

    private func plan(
        build: String = "b212", attached: String? = "b212", uses: Bool? = nil, timing: ReleaseTiming = .manual, isPhased: Bool = true,
        phasedID: String? = nil, events: [String] = [], open: VersionSubmission? = nil
    ) -> SubmissionPlan {
        SubmissionPlan(
            appID: "42", versionID: "v14", platform: "IOS", buildID: build, attachedBuildID: attached, usesNonExemptEncryption: uses,
            timing: timing, isPhased: isPhased, phasedReleaseID: phasedID, eventIDs: events, openSubmission: open
        )
    }

    // MARK: - Which version

    @Test func theVersionInReviewIsFollowedBeforeTheOneBeingPrepared() {
        let versions = [
            version("1.5", "PREPARE_FOR_SUBMISSION", created: "2026-11-10"),
            version("1.4", "IN_REVIEW", created: "2026-11-01"),
            version("1.3", "READY_FOR_DISTRIBUTION", created: "2026-10-01"),
        ]
        #expect(LiveReleaseServices.followed(versions, platform: "IOS")?.id == "1.4")
    }

    @Test func otherwiseTheOneBeingPreparedThenTheLiveOne() {
        let live = version("1.3", "READY_FOR_DISTRIBUTION", created: "2026-10-01")
        let old = version("1.2", "REPLACED_WITH_NEW_VERSION", created: "2026-09-01")
        let next = version("1.4", "PREPARE_FOR_SUBMISSION", created: "2026-11-01")
        #expect(LiveReleaseServices.followed([old, live, next], platform: "IOS")?.id == "1.4")
        #expect(LiveReleaseServices.followed([old, live], platform: "IOS")?.id == "1.3")
        #expect(LiveReleaseServices.followed([], platform: "IOS") == nil)
    }

    @Test func thePlatformPicksAmongVersions() {
        let iOS = version("1.4", "PREPARE_FOR_SUBMISSION", created: "2026-11-01")
        let mac = version("2.0", "WAITING_FOR_REVIEW", platform: "MAC_OS", created: "2026-11-02")
        #expect(LiveReleaseServices.followed([iOS, mac], platform: "IOS")?.id == "1.4")
        #expect(LiveReleaseServices.followed([iOS, mac], platform: "MAC_OS")?.id == "2.0")
        // Without a platform, the one on its way.
        #expect(LiveReleaseServices.followed([iOS, mac], platform: nil)?.id == "2.0")
        // A platform the app doesn't have falls back to what there is.
        #expect(LiveReleaseServices.followed([iOS], platform: "TV_OS")?.id == "1.4")
    }

    // MARK: - Submitting

    @Test func submittingSetsTheReleaseThenSendsOneSubmission() async throws {
        let transport = FakeHTTPTransport([Self.done, Self.done, Self.createdSubmission, Self.done, Self.done])
        try await services(transport).submit(plan())
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/appStoreVersionPhasedReleases",
            "POST /v1/reviewSubmissions",
            "POST /v1/reviewSubmissionItems",
            "PATCH /v1/reviewSubmissions/sub1",
        ])
        let release = body(transport.requests[0])["attributes"] as? [String: Any]
        #expect(release?["releaseType"] as? String == "MANUAL")
        #expect(release?["earliestReleaseDate"] is NSNull)
        let item = body(transport.requests[3])["relationships"] as? [String: Any]
        #expect(((item?["appStoreVersion"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "v14")
        #expect(((item?["reviewSubmission"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "sub1")
        #expect((body(transport.requests[4])["attributes"] as? [String: Any])?["submitted"] as? Bool == true)
    }

    @Test func anotherBuildTheEncryptionAnswerAndEventsGoFirst() async throws {
        let transport = FakeHTTPTransport(Array(repeating: Self.done, count: 3) + [Self.createdSubmission] + Array(repeating: Self.done, count: 3))
        let date = Date(timeIntervalSince1970: 1_794_830_400)
        try await services(transport).submit(plan(
            build: "b213", uses: false, timing: .scheduled(date), isPhased: false, events: ["event-mood"]
        ))
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14/relationships/build",
            "PATCH /v1/builds/b213",
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/reviewSubmissions",
            "POST /v1/reviewSubmissionItems",
            "POST /v1/reviewSubmissionItems",
            "PATCH /v1/reviewSubmissions/sub1",
        ])
        #expect((body(transport.requests[1])["attributes"] as? [String: Any])?["usesNonExemptEncryption"] as? Bool == false)
        let release = body(transport.requests[2])["attributes"] as? [String: Any]
        #expect(release?["releaseType"] as? String == "SCHEDULED")
        #expect(release?["earliestReleaseDate"] as? String == "2026-11-16T12:00:00Z")
        let event = body(transport.requests[5])["relationships"] as? [String: Any]
        #expect(((event?["appEvent"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "event-mood")
    }

    @Test func anOpenSubmissionIsReusedAndAPhasedReleaseNotWantedIsRemoved() async throws {
        let open = VersionSubmission(id: "sub7", state: "READY_FOR_REVIEW", versionID: "v14", eventIDs: ["event-mood"])
        let transport = FakeHTTPTransport([Self.done, Self.noContent, Self.done])
        try await services(transport).submit(plan(isPhased: false, phasedID: "ph1", events: ["event-mood"], open: open))
        // The version and the event are in it already: only submit it.
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "DELETE /v1/appStoreVersionPhasedReleases/ph1",
            "PATCH /v1/reviewSubmissions/sub7",
        ])
    }

    @Test func aFailedStepStopsBeforeSubmitting() async {
        let refused = CannedHTTPResponse(statusCode: 409, body: #"""
        {"errors":[{"status":"409","code":"STATE_ERROR","title":"Not allowed","detail":"The build is invalid."}]}
        """#)
        let transport = FakeHTTPTransport([refused])
        await #expect(throws: AppStoreConnectError.self) {
            try await services(transport).submit(plan())
        }
        #expect(transport.requests.count == 1)
    }

    // MARK: - After submitting

    @Test func cancelingAndSubmittingAgainUpdateTheSubmission() async throws {
        let transport = FakeHTTPTransport([Self.done, Self.done])
        try await services(transport).cancelSubmission("sub1")
        try await services(transport).resubmit("sub1")
        #expect(calls(transport) == ["PATCH /v1/reviewSubmissions/sub1", "PATCH /v1/reviewSubmissions/sub1"])
        #expect((body(transport.requests[0])["attributes"] as? [String: Any])?["canceled"] as? Bool == true)
        #expect((body(transport.requests[1])["attributes"] as? [String: Any])?["submitted"] as? Bool == true)
    }

    @Test func releasingAsksForAReleaseOfTheVersion() async throws {
        let transport = FakeHTTPTransport([Self.done])
        try await services(transport).release(versionID: "v14")
        #expect(calls(transport) == ["POST /v1/appStoreVersionReleaseRequests"])
        let relationships = body(transport.requests[0])["relationships"] as? [String: Any]
        #expect(((relationships?["appStoreVersion"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "v14")
    }

    @Test func pausingResumingAndReleasingToEveryoneSetThePhasedReleasesState() async throws {
        let transport = FakeHTTPTransport([Self.done, Self.done, Self.done])
        try await services(transport).setPhasedRelease("ph1", to: .paused)
        try await services(transport).setPhasedRelease("ph1", to: .active)
        try await services(transport).setPhasedRelease("ph1", to: .complete)
        #expect(Set(calls(transport)) == ["PATCH /v1/appStoreVersionPhasedReleases/ph1"])
        let states = transport.requests.map { (body($0)["attributes"] as? [String: Any])?["phasedReleaseState"] as? String }
        #expect(states == ["PAUSED", "ACTIVE", "COMPLETE"])
    }

    @Test func eventsCanGoToAppReviewOnTheirOwn() async throws {
        let transport = FakeHTTPTransport([Self.createdSubmission, Self.done, Self.done])
        let app = StoreApp(id: "42", name: "Lumen", bundleID: "dev.lumen", sku: nil, primaryLocale: "en-US")
        try await services(transport).submitEvents(["event-winter"], for: app, platform: "IOS")
        #expect(calls(transport) == ["POST /v1/reviewSubmissions", "POST /v1/reviewSubmissionItems", "PATCH /v1/reviewSubmissions/sub1"])
        try await services(transport).submitEvents([], for: app, platform: "IOS")
        #expect(transport.requests.count == 3)
    }

    @Test func buildsAndPhasedReleasesAreReadFromTheirResources() {
        let build = LiveReleaseServices.build(AppStoreConnectResource(type: "builds", id: "b1", attributes: BuildAttributes(
            version: "212", uploadedDate: "2026-11-15T10:00:00Z", processingState: "VALID", expired: false, usesNonExemptEncryption: false
        )))
        #expect(build.number == "212")
        #expect(build.isSelectable)
        #expect(build.usesNonExemptEncryption == false)
        let unknown = LiveReleaseServices.build(AppStoreConnectResource(type: "builds", id: "b2", attributes: BuildAttributes(
            version: "213", uploadedDate: nil, processingState: nil, expired: nil, usesNonExemptEncryption: nil
        )))
        #expect(unknown.processing == .processing)
        #expect(!unknown.isSelectable)
    }
}
