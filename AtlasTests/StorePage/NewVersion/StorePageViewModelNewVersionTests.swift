//
//  StorePageViewModelNewVersionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// New Version… on the Store Page: offered only when no version is in
/// progress, starting at the live number plus one, and queued in Review &
/// Push as one change.
@MainActor
@Suite("Store Page new version")
struct StorePageViewModelNewVersionTests {
    private let queue = ChangeQueue()

    private func makeModel(_ contents: [StorePageContent] = [StorePageContentFixtures.liveOnly]) async -> StorePageViewModel {
        let model = StorePageViewModel(app: StorePageContentFixtures.app, services: FakeStorePageServices(contents: contents), queue: queue)
        await model.load()
        return model
    }

    @Test func onlyTheLiveVersionStartsAtItsNumberPlusOne() async {
        let model = await makeModel()
        #expect(model.canCreateVersion)
        #expect(model.newVersionPlatforms == ["IOS"])
        #expect(model.newVersionStart == NewAppVersion(versionString: "1.10", platform: "IOS"))
        #expect(model.latestVersion(on: "IOS")?.versionString == "1.9")
    }

    @Test func aVersionInProgressMeansNoNewOne() async {
        let model = await makeModel([StorePageContentFixtures.editable, StorePageContentFixtures.live])
        #expect(!model.canCreateVersion)
        let problem = model.newVersionProblem(NewAppVersion(versionString: "2.1", platform: "IOS"))
        #expect(problem == .inProgress(versionString: "2.0", state: .prepareForSubmission))
    }

    @Test func addingQueuesItAndClosesTheSheet() async throws {
        let model = await makeModel()
        model.openNewVersion()
        #expect(model.sheet == .newVersion)

        #expect(model.queueNewVersion(NewAppVersion(versionString: " 2.0 ", platform: "IOS")))
        #expect(model.sheet == nil)
        #expect(model.toast?.text == "Version 2.0 waits in Review & Push. Once it’s pushed, edit its texts here.")
        let change = try #require(queue.change(id: "appStoreVersion.app1.IOS"))
        #expect(change.source == .you)
        #expect(change.title == "Version 2.0")
        #expect(model.queuedNewVersions == [NewAppVersion(versionString: "2.0", platform: "IOS")])
        #expect(!model.canCreateVersion)
    }

    @Test func aNumberAppStoreConnectWouldRefuseIsntQueued() async {
        let model = await makeModel()
        model.openNewVersion()
        #expect(model.newVersionProblem(NewAppVersion(versionString: "1.9", platform: "IOS")) == .notHigher(latest: "1.9"))
        #expect(!model.queueNewVersion(NewAppVersion(versionString: "1.9", platform: "IOS")))
        #expect(!model.queueNewVersion(NewAppVersion(versionString: "2.0 beta", platform: "IOS")))
        #expect(model.sheet == .newVersion)
        #expect(queue.changes.isEmpty)
    }

    @Test func anotherNumberReplacesTheQueuedOne() async {
        let model = await makeModel()
        model.queueNewVersion(NewAppVersion(versionString: "2.0", platform: "IOS"))
        model.queueNewVersion(NewAppVersion(versionString: "1.10", platform: "IOS"))
        #expect(queue.changes.count == 1)
        #expect(model.queuedNewVersions.map(\.versionString) == ["1.10"])
    }
}
