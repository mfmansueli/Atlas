//
//  SubmitProductsViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Submit sheet's subscriptions and in-app purchases: every one Ready
/// to Submit starts ticked and goes in the plan; an untick keeps it out.
@MainActor
@Suite("Release · Submit sheet products")
struct SubmitProductsViewModelTests {
    typealias Data = DebugReleaseData

    private let release = FakeReleaseServices()
    private let queue = ChangeQueue()
    private let store = DebugReleaseData.store(.prepare)
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]

    private static let annual = SubmissionProduct(id: "s1", productID: "lumen.plus.annual", name: "Annual", isSubscription: true, isFirst: true)
    private static let lifetime = SubmissionProduct(id: "p1", productID: "lumen.lifetime", name: "Lifetime", isSubscription: false)

    /// Lumen 1.4 with everything ready, no In-App Events, `products`
    /// Ready to Submit.
    private func makeModel(_ products: [SubmissionProduct]) async -> ReleaseViewModel {
        var services = ReleaseDebugScenes.services(.prepare, encryption: .exempt)
        services.inAppEvents = FakeInAppEventsServices([])
        var storePage = DebugStorePageServices()
        storePage.whatsNew = Data.whatsNew.merging([Data.missingLocale: Data.suggestedWhatsNew]) { _, new in new }
        services.storePage = storePage
        var status = Data.status(.prepare)
        status.productsToSubmit = products
        release.status = status
        services.release = release
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport(), now: { Data.today })
        let model = ReleaseViewModel(app: app, services: services, store: store, queue: queue, suggestions: FieldSuggestionStore(), push: push)
        model.now = { Data.today }
        model.eventsStore = InAppEventsStore()
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        return model
    }

    @Test func everyReadyProductStartsTicked() async {
        let model = await makeModel([Self.annual, Self.lifetime])
        #expect(model.offeredProducts.map(\.id) == ["s1", "p1"])
        #expect(model.options.productIDs == ["s1", "p1"])
    }

    @Test func theTickedProductsGoInThePlan() async throws {
        let model = await makeModel([Self.annual, Self.lifetime])
        model.setProduct("p1", goesWithVersion: false)
        try #require(model.canSubmit)
        #expect(await model.submit())
        #expect(release.plans.last?.products == [Self.annual])
    }

    @Test func withoutProductsThePlanHasNone() async throws {
        let model = await makeModel([])
        try #require(model.canSubmit)
        #expect(await model.submit())
        #expect(release.plans.last?.products.isEmpty == true)
    }

    @Test func readingAgainKeepsThePersonsTicksAndTicksNewOnes() {
        var before = Data.status(.prepare)
        before.productsToSubmit = [Self.annual, Self.lifetime]
        var now = before
        let tips = SubmissionProduct(id: "p2", productID: "lumen.tips", name: "Tips", isSubscription: false)
        now.productsToSubmit = [Self.lifetime, tips]
        // Lifetime was unticked; Annual went (submitted elsewhere); Tips is new.
        #expect(ReleaseViewModel.keptProductIDs(["s1"], before: before, now: now) == ["p2"])
    }

    @Test func aProposalsProductsReplaceTheTicks() async {
        let model = await makeModel([Self.annual, Self.lifetime])
        let submission = ReleaseProposalSubmission(
            buildID: "build-212", buildNumber: "212", releaseType: "MANUAL", isPhased: true, productIDs: ["p1", "unknown"]
        )
        model.apply(submission)
        #expect(model.options.productIDs == ["p1"])
        #expect(submission.lines(version: "1.4") { $0 }.contains("With 2 subscriptions or in-app purchases"))
    }
}
#endif
