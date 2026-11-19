//
//  NewAppVersionChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// "Create version 1.5" in Review & Push: one `POST /v1/appStoreVersions`
/// per platform, read back from the queue, and a creation row rather than
/// a new page.
@MainActor
@Suite("NewAppVersionChangeBuilder")
struct NewAppVersionChangeBuilderTests {
    private let builder = NewAppVersionChangeBuilder(appID: "app1")
    private let version = NewAppVersion(versionString: "2.1", platform: "IOS")

    @Test func theChangeCreatesTheVersionForTheApp() throws {
        let change = builder.change(for: version, showsPlatform: false)
        #expect(change.id == "appStoreVersion.app1.IOS")
        #expect(change.section == .storePage)
        #expect(change.title == "Version 2.1")
        #expect(change.creation?.title == "Create version 2.1")
        #expect(change.creation?.fields.isEmpty == true)
        #expect(change.restoreRequests.isEmpty)

        let request = try #require(change.requests.first)
        #expect(change.requests.count == 1)
        #expect(request.method == .post)
        #expect(request.path == "/v1/appStoreVersions")
        let body = try #require(request.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try #require(object["data"] as? [String: Any])
        #expect(data["type"] as? String == "appStoreVersions")
        #expect(data["attributes"] as? [String: String] == ["platform": "IOS", "versionString": "2.1"])
        let app = ((data["relationships"] as? [String: Any])?["app"] as? [String: Any])?["data"] as? [String: String]
        #expect(app == ["type": "apps", "id": "app1"])
    }

    @Test func anAppOnSeveralPlatformsNamesIt() {
        let mac = builder.change(
            for: NewAppVersion(versionString: "1.3", platform: "MAC_OS"),
            showsPlatform: true,
            source: .assistant(client: "Claude Code"),
            reason: "MARKETING_VERSION is 1.3."
        )
        #expect(mac.id == "appStoreVersion.app1.MAC_OS")
        #expect(mac.title == "Version 1.3 · macOS")
        #expect(mac.creation?.detail.hasSuffix("MARKETING_VERSION is 1.3.") == true)
        #expect(mac.creation?.source == .assistant(client: "Claude Code"))
    }

    @Test func theQueueSaysWhichVersionsWait() {
        let queue = ChangeQueue()
        queue.upsert(builder.change(for: version, showsPlatform: false))
        queue.upsert(NewAppVersionChangeBuilder(appID: "app2").change(for: version, showsPlatform: false))
        let queued = builder.queued(in: queue)
        #expect(queued.map(\.id) == ["appStoreVersion.app1.IOS"])
        #expect(queued.compactMap(NewAppVersionChangeBuilder.version(of:)) == [version])
    }

    @Test func reviewCountsItAsAChangeNotAPage() {
        let change = builder.change(for: version, showsPlatform: false)
        let group = ReviewChangeGroup(id: "storePage", title: "Store Page · New version", section: .storePage, changes: [change])
        #expect(group.creations.count == 1)
        #expect(group.countText == "1 change")
        #expect(PushRecord.title(for: [change]) == "Store Page · Version 2.1")
    }
}
