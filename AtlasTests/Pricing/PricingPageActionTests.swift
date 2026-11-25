//
//  PricingPageActionTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Add Subscription… in the toolbar (board 80): on once the products are
/// read, and it opens Create Subscription from Prices, also from Retention.
@MainActor
@Suite("Pricing · page action")
struct PricingPageActionTests {
    private func model(load: Bool = true) async -> PricingViewModel {
        let model = PricingViewModel(
            app: PricingModelFixtures.app, services: DebugPricingServices(), queue: ChangeQueue(),
            modes: PricingModeStore(defaults: nil), commission: .smallBusiness
        )
        if load { await model.load() }
        return model
    }

    @Test func beforeTheReadItsOff() async {
        let model = await model(load: false)
        #expect(model.pageActionState == .disabled(reason: nil))
        model.startPageAction()
        #expect(!model.isNewSubscriptionSheetPresented)
    }

    @Test func itOpensCreateSubscription() async {
        let model = await model()
        #expect(model.pageActionState == .enabled)
        model.startPageAction()
        #expect(model.isNewSubscriptionSheetPresented)
    }

    @Test func fromRetentionItGoesBackToPrices() async {
        let model = await model()
        model.page = .retention
        model.startPageAction()
        #expect(model.page == .prices)
        #expect(model.isNewSubscriptionSheetPresented)
    }

    @Test func theIntentIsHandled() async {
        let model = await model()
        #expect(await model.handle(.pageAction))
        #expect(model.isNewSubscriptionSheetPresented)
    }
}
#endif
