//
//  PricingProductDetailsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The product page's Details tab: rows from the catalog, the card and
/// App Store Connect's availability and Family Sharing; nothing invented
/// for what isn't read.
@MainActor
@Suite("Pricing product details")
struct PricingProductDetailsTests {
    private let catalog = DebugPricingCatalog.catalog(for: PricingModelFixtures.appID)

    private func product(_ id: String) throws -> PricingProduct {
        try #require(catalog.product(id: id))
    }

    private func make(
        _ product: PricingProduct,
        price: String? = "$39.99",
        isReadingPrices: Bool = false,
        facts: LoadState<PricingProductFacts>,
        commission: Commission = .standard
    ) -> PricingProductDetails {
        PricingProductDetails.make(
            product: product,
            group: catalog.group(containing: product.id),
            basePrice: price.map { "\($0) in the United States" },
            isReadingPrices: isReadingPrices,
            facts: facts,
            territoryTotal: 175,
            commission: commission
        )
    }

    @Test func aSubscriptionShowsEveryRow() throws {
        let annual = try product(DebugPricingCatalog.lumenAnnualID)
        let facts = PricingProductFacts(availableTerritoryCount: 175, availableInNewTerritories: true, isFamilySharable: false)
        let details = make(annual, facts: .loaded(facts))
        #expect(details.rows.map(\.kind) == [.type, .productID, .group, .basePrice, .availability, .familySharing, .commission, .taxCategory])
        #expect(details.rows.first { $0.kind == .productID }?.value == annual.productID)
        #expect(details.rows.first { $0.kind == .type }?.value == "Subscription · 1 year")
        #expect(details.rows.first { $0.kind == .group }?.value == catalog.group(containing: annual.id)?.name)
        #expect(details.rows.first { $0.kind == .basePrice }?.value == "$39.99 in the United States")
        #expect(details.rows.first { $0.kind == .availability }?.value == "175 of 175 countries and regions")
        #expect(details.rows.first { $0.kind == .familySharing }?.value == "Off")
    }

    @Test func anInAppPurchaseHasNoGroup() throws {
        let lifetime = try product(DebugPricingCatalog.lumenLifetimeID)
        let details = make(lifetime, facts: .loaded(PricingProductFacts(availableTerritoryCount: 12, isFamilySharable: true)))
        #expect(!details.rows.contains { $0.kind == .group })
        #expect(details.rows.first { $0.kind == .availability }?.value == "12 of 175 countries and regions")
        #expect(details.rows.first { $0.kind == .familySharing }?.value == "On")
    }

    @Test func whatIsBeingReadHasNoValueYet() throws {
        let annual = try product(DebugPricingCatalog.lumenAnnualID)
        let details = make(annual, price: nil, isReadingPrices: true, facts: .loading)
        for kind in [PricingProductDetailKind.basePrice, .availability, .familySharing] {
            let row = try #require(details.rows.first { $0.kind == kind })
            #expect(row.value == nil)
        }
    }

    @Test func whatCouldNotBeReadIsLeftOut() throws {
        let annual = try product(DebugPricingCatalog.lumenAnnualID)
        let failed = make(annual, price: nil, facts: .failed("Availability and Family Sharing didn’t load."))
        #expect(failed.rows.map(\.kind) == [.type, .productID, .group, .commission, .taxCategory])

        let unanswered = make(annual, facts: .loaded(PricingProductFacts()))
        #expect(!unanswered.rows.contains { $0.kind == .availability || $0.kind == .familySharing })
    }

    @Test func availabilitySaysWhereItIsSold() {
        #expect(PricingProductDetails.availabilityText(0, of: 175) == "Not available in any country or region yet")
        #expect(PricingProductDetails.availabilityText(175, of: 175) == "175 of 175 countries and regions")
        #expect(PricingProductDetails.availabilityText(3, of: 2) == "3 of 3 countries and regions")
    }

    @Test func theViewModelReadsTheFactsOnce() async throws {
        let model = await PricingModelFixtures.viewModel()
        await model.productsTask?.value
        let reader = CountingFactsReader()
        model.productFacts.reader = reader
        let annual = try PricingModelFixtures.annual()
        await model.loadProductFacts(for: annual)
        await model.loadProductFacts(for: annual)
        #expect(reader.count == 1)
        let details = model.productDetails(for: annual)
        #expect(details.rows.first { $0.kind == .availability }?.value == "175 of 175 countries and regions")
        #expect(details.rows.first { $0.kind == .basePrice }?.value?.hasSuffix("in the United States") == true)

        model.productFacts.forget()
        await model.loadProductFacts(for: annual)
        #expect(reader.count == 2)
    }

    @Test func aFailedReadSaysWhy() async throws {
        let store = PricingProductFactsStore()
        store.reader = DebugPricingProductFactsReader(fails: true)
        let annual = try PricingModelFixtures.annual()
        await store.load(annual) { nil }
        #expect(store.state(for: annual.id).errorMessage?.hasPrefix("Availability and Family Sharing didn’t load.") == true)
        #expect(store.failure(for: annual.id) != nil)
    }

    @Test func withoutAReaderOrTransportItFails() async throws {
        let store = PricingProductFactsStore()
        let annual = try PricingModelFixtures.annual()
        await store.load(annual) { nil }
        #expect(store.state(for: annual.id).errorMessage == "Availability and Family Sharing didn’t load.")
    }

    /// Apple's commission is the rate Proceeds use; the tax category isn't
    /// in the API, so the row says where it's set.
    @Test func theCommissionFollowsSettings() throws {
        let annual = try product(DebugPricingCatalog.lumenAnnualID)
        let details = make(annual, facts: .loaded(PricingProductFacts(availableTerritoryCount: 175)), commission: .smallBusiness)
        #expect(details.rows.first { $0.kind == .commission }?.value == "15% (Small Business Program)")
        #expect(details.rows.last?.kind == .taxCategory)
    }
}
#endif
