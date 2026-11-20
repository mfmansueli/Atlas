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
    private static let none = CannedHTTPResponse(statusCode: 200, body: #"{"data":null}"#)
    private static let noneOpen = CannedHTTPResponse(statusCode: 200, body: #"{"data":[]}"#)
    private static let phased = CannedHTTPResponse(
        statusCode: 200, body: #"{"data":{"type":"appStoreVersionPhasedReleases","id":"ph1","attributes":{"phasedReleaseState":"INACTIVE"}}}"#
    )
    private static let openWithTheVersion = CannedHTTPResponse(statusCode: 200, body: #"""
    {"data":[{"type":"reviewSubmissions","id":"sub7","attributes":{"state":"READY_FOR_REVIEW"},
    "relationships":{"appStoreVersionForReview":{"data":{"type":"appStoreVersions","id":"v14"}}}}]}
    """#)
    private static let openEmpty = CannedHTTPResponse(
        statusCode: 200, body: #"{"data":[{"type":"reviewSubmissions","id":"sub7","attributes":{"state":"READY_FOR_REVIEW"}}]}"#
    )
    private static let moodItem = CannedHTTPResponse(statusCode: 200, body: #"""
    {"data":[{"type":"reviewSubmissionItems","id":"i1","attributes":{"state":"READY_FOR_REVIEW"},
    "relationships":{"appEvent":{"data":{"type":"appEvents","id":"event-mood"}}}}]}
    """#)

    /// What App Store Connect has while submitting: the version's phased
    /// release and its open submission, read before either is made.
    private static func reads(
        phased: CannedHTTPResponse = none, open: CannedHTTPResponse = noneOpen, items: CannedHTTPResponse = noneOpen
    ) -> [(text: String, response: CannedHTTPResponse)] {
        [("v14/appStoreVersionPhasedRelease", phased), ("/apps/42/reviewSubmissions", open), ("/reviewSubmissions/sub7/items", items)]
    }

    private func services(_ transport: FakeHTTPTransport) -> LiveReleaseServices {
        LiveReleaseServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        let object = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        return object?["data"] as? [String: Any] ?? [:]
    }

    /// The writes, in order; the reads are routed.
    private func calls(_ transport: FakeHTTPTransport) -> [String] {
        transport.requests.filter { $0.httpMethod != "GET" }.map { "\($0.httpMethod ?? "") \($0.url?.path() ?? "")" }
    }

    private func writes(_ transport: FakeHTTPTransport) -> [URLRequest] {
        transport.requests.filter { $0.httpMethod != "GET" }
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
        events: [String] = []
    ) -> SubmissionPlan {
        SubmissionPlan(
            appID: "42", versionID: "v14", platform: "IOS", buildID: build, attachedBuildID: attached, usesNonExemptEncryption: uses,
            timing: timing, isPhased: isPhased, eventIDs: events
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
        let transport = FakeHTTPTransport([Self.done, Self.done, Self.createdSubmission, Self.done, Self.done], routes: Self.reads())
        try await services(transport).submit(plan())
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/appStoreVersionPhasedReleases",
            "POST /v1/reviewSubmissions",
            "POST /v1/reviewSubmissionItems",
            "PATCH /v1/reviewSubmissions/sub1",
        ])
        let sent = writes(transport)
        let release = body(sent[0])["attributes"] as? [String: Any]
        #expect(release?["releaseType"] as? String == "MANUAL")
        #expect(release?["earliestReleaseDate"] is NSNull)
        let item = body(sent[3])["relationships"] as? [String: Any]
        #expect(((item?["appStoreVersion"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "v14")
        #expect(((item?["reviewSubmission"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "sub1")
        #expect((body(sent[4])["attributes"] as? [String: Any])?["submitted"] as? Bool == true)
    }

    @Test func anotherBuildTheEncryptionAnswerAndEventsGoFirst() async throws {
        let transport = FakeHTTPTransport(
            Array(repeating: Self.done, count: 3) + [Self.createdSubmission] + Array(repeating: Self.done, count: 3), routes: Self.reads()
        )
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
        let sent = writes(transport)
        #expect((body(sent[1])["attributes"] as? [String: Any])?["usesNonExemptEncryption"] as? Bool == false)
        let release = body(sent[2])["attributes"] as? [String: Any]
        #expect(release?["releaseType"] as? String == "SCHEDULED")
        #expect(release?["earliestReleaseDate"] as? String == "2026-11-16T12:00:00Z")
        let event = body(sent[5])["relationships"] as? [String: Any]
        #expect(((event?["appEvent"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "event-mood")
    }

    @Test func anOpenSubmissionIsReusedAndAPhasedReleaseNotWantedIsRemoved() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.noContent, Self.done], routes: Self.reads(phased: Self.phased, open: Self.openWithTheVersion, items: Self.moodItem)
        )
        try await services(transport).submit(plan(isPhased: false, events: ["event-mood"]))
        // The version and the event are in it already: only submit it.
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "DELETE /v1/appStoreVersionPhasedReleases/ph1",
            "PATCH /v1/reviewSubmissions/sub7",
        ])
    }

    /// SimProps's second Submit: the first had made the phased release and
    /// an empty submission before it stopped. Neither is made again.
    @Test func whatAnEarlierAttemptMadeIsUsedNotMadeAgain() async throws {
        let transport = FakeHTTPTransport([Self.done, Self.done, Self.done], routes: Self.reads(phased: Self.phased, open: Self.openEmpty))
        try await services(transport).submit(plan())
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/reviewSubmissionItems",
            "PATCH /v1/reviewSubmissions/sub7",
        ])
    }

    /// SimProps 1.0.0 after its rejection: the submission with unresolved
    /// issues still carries the version and is sent again, not a new empty
    /// one App Store Connect refuses.
    @Test func aRejectedVersionsSubmissionIsSentAgain() async throws {
        let rejected = CannedHTTPResponse(statusCode: 200, body: #"""
        {"data":[{"type":"reviewSubmissions","id":"sub7","attributes":{"state":"UNRESOLVED_ISSUES"},
        "relationships":{"appStoreVersionForReview":{"data":{"type":"appStoreVersions","id":"v14"}}}}]}
        """#)
        let transport = FakeHTTPTransport([Self.done, Self.done], routes: Self.reads(phased: Self.phased, open: rejected))
        try await services(transport).submit(plan())
        #expect(calls(transport) == ["PATCH /v1/appStoreVersions/v14", "PATCH /v1/reviewSubmissions/sub7"])
    }

    /// A submission that carries the version but can't take more (sent
    /// already) doesn't stand in for the new one: the new one gets the
    /// version.
    @Test func aNewSubmissionAlwaysGetsTheVersion() async throws {
        let sent = CannedHTTPResponse(statusCode: 200, body: #"""
        {"data":[{"type":"reviewSubmissions","id":"sub7","attributes":{"state":"WAITING_FOR_REVIEW"},
        "relationships":{"appStoreVersionForReview":{"data":{"type":"appStoreVersions","id":"v14"}}}}]}
        """#)
        let transport = FakeHTTPTransport([Self.done, Self.createdSubmission, Self.done, Self.done], routes: Self.reads(phased: Self.phased, open: sent))
        try await services(transport).submit(plan())
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/reviewSubmissions",
            "POST /v1/reviewSubmissionItems",
            "PATCH /v1/reviewSubmissions/sub1",
        ])
    }

    @Test func aFailedStepStopsBeforeSubmitting() async {
        let refused = CannedHTTPResponse(statusCode: 409, body: #"""
        {"errors":[{"status":"409","code":"STATE_ERROR","title":"Not allowed","detail":"The build is invalid."}]}
        """#)
        let transport = FakeHTTPTransport([refused])
        let error = await #expect(throws: SubmissionFailure.self) {
            try await services(transport).submit(plan())
        }
        #expect(error?.step == .release)
        #expect(error?.submissionID == nil)
        #expect(error?.underlying == .rejected(statusCode: 409, code: "STATE_ERROR", detail: "The build is invalid."))
        #expect(transport.requests.count == 1)
    }

    /// Alba 1.2.0: App Store Connect took the version into the new
    /// submission, then refused an event without a deep link. The failure
    /// says which step, which event, and what the draft holds.
    @Test func aRefusedEventNamesItAndTheDraftLeft() async {
        let refused = CannedHTTPResponse(statusCode: 409, body: #"""
        {"errors":[{"status":"409","code":"ENTITY_ERROR.ATTRIBUTE.REQUIRED","title":"An attribute value is required.",
        "detail":"You must provide a value for the attribute 'deepLink' with this request"}]}
        """#)
        let transport = FakeHTTPTransport(
            [Self.done, Self.createdSubmission, Self.done, Self.done, refused], routes: Self.reads(phased: Self.phased)
        )
        let error = await #expect(throws: SubmissionFailure.self) {
            try await services(transport).submit(plan(events: ["event-gratitude", "event-mood"]))
        }
        #expect(error?.step == .addEvent("event-mood"))
        #expect(error?.submissionID == "sub1")
        #expect(error?.hasVersion == true)
        #expect(error?.eventIDs == ["event-gratitude"])
        #expect(error?.message.contains("'deepLink'") == true)
        // Nothing was sent to App Review.
        #expect(!calls(transport).contains("PATCH /v1/reviewSubmissions/sub1"))
    }

    /// An event unticked after a refused try leaves the draft it was added
    /// to, so Submit sends the version without it.
    @Test func anUntickedEventLeavesTheReusedDraft() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.noContent, Self.done], routes: Self.reads(phased: Self.phased, open: Self.openWithTheVersion, items: Self.moodItem)
        )
        try await services(transport).submit(plan(events: []))
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "DELETE /v1/reviewSubmissionItems/i1",
            "PATCH /v1/reviewSubmissions/sub7",
        ])
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
