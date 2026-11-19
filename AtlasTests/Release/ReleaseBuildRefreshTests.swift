//
//  ReleaseBuildRefreshTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Submit sheet reads the builds again while it's open: SimProps's
/// newest upload didn't show because the list was read once, when the app
/// was opened. Lumen 1.4's sample builds: 213 processing, 212 and 211 ready.
@MainActor
@Suite("Release · builds refresh")
struct ReleaseBuildRefreshTests {
    typealias Data = DebugReleaseData

    private let release = FakeReleaseServices()
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]

    /// Lumen 1.4 before submitting, with no build attached yet, so the
    /// sheet starts on the newest ready one (212).
    private func makeModel() async -> ReleaseViewModel {
        var services = ReleaseDebugScenes.services(.prepare)
        release.status = unattached(Data.status(.prepare))
        services.release = release
        let queue = ChangeQueue()
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let model = ReleaseViewModel(
            app: app, services: services, store: Data.store(.prepare), queue: queue, suggestions: FieldSuggestionStore(), push: push
        )
        model.now = { Data.today }
        await model.load()
        return model
    }

    private func unattached(_ status: ReleaseStatus?) -> ReleaseStatus? {
        var status = status
        status?.attachedBuildID = nil
        return status
    }

    /// App Store Connect now: 213 processed, and `extra` uploaded since.
    private func processed(_ change: (inout [ReleaseBuild]) -> Void = { _ in }) -> ReleaseStatus? {
        var status = unattached(Data.status(.prepare))
        if let index = status?.builds.firstIndex(where: { $0.id == "build-213" }) { status?.builds[index].processing = .valid }
        if var builds = status?.builds {
            change(&builds)
            status?.builds = builds
        }
        return status
    }

    @Test func aBuildProcessedSinceIsChosenWhenThePersonHadntPicked() async {
        let model = await makeModel()
        #expect(model.options.buildID == "build-212")

        release.status = processed { $0.insert(ReleaseBuild(id: "build-214", number: "214", uploaded: Data.today, processing: .processing), at: 0) }
        await model.refreshStatus()
        #expect(model.status?.builds.map(\.number) == ["214", "213", "212", "211"])
        #expect(model.options.buildID == "build-213")
        #expect(!model.isRefreshingBuilds)
    }

    @Test func thePersonsPickAndAnswersAreKept() async {
        let model = await makeModel()
        model.options.buildID = "build-211"
        model.options.timing = .afterApproval
        model.options.pushesChanges = false

        release.status = processed()
        await model.refreshStatus()
        #expect(model.options.buildID == "build-211")
        #expect(model.options.timing == .afterApproval)
        #expect(!model.options.pushesChanges)
    }

    @Test func aPickedBuildThatExpiredFallsBackToTheNewestReady() async {
        let model = await makeModel()
        model.options.buildID = "build-211"

        release.status = processed { builds in
            if let index = builds.firstIndex(where: { $0.id == "build-211" }) { builds[index].isExpired = true }
        }
        await model.refreshStatus()
        #expect(model.options.buildID == "build-213")
    }

    @Test func aVersionThatMovedOnLoadsAgain() async {
        let model = await makeModel()
        release.status = Data.status(.waiting)
        await model.refreshStatus()
        #expect(model.phase == Data.status(.waiting).phase)
    }
}
#endif
