//
//  AppPriceDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Pricing's App Price and Availability DEBUG scenes
/// (`-AtlasDebugScene <id>`):
///
/// - `app-price-none`: Quiet Timer, with no price, no availability and no
///   subscriptions, as a new app is in App Store Connect.
/// - `app-price-add`, `app-availability-setup`: the same with Add Pricing…
///   or Set Up Availability… open.
/// - `app-price-queued`: Quiet Timer's $2.99 price and availability
///   everywhere, waiting in Review & Push.
/// - `app-price-set`: Tempo Metronome at $2.99, sold everywhere but China
///   mainland, on the Prices page's cards.
/// - `app-price-change`, `app-availability-edit`: Tempo's Change Price… or
///   Edit Countries and Regions… open.
/// - `app-price-error`: both cards after a failed read.
enum AppPriceDebugScenes {
    typealias AppIDs = DebugFixtures.AppID

    static let ids = [
        "app-price-none", "app-price-add", "app-availability-setup", "app-price-queued",
        "app-price-set", "app-price-change", "app-availability-edit", "app-price-error",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "app-price-none": newApp()
        case "app-price-add": newApp(opens: .price)
        case "app-availability-setup": newApp(opens: .availability)
        case "app-price-queued": newApp(pendingChanges: queuedChanges())
        case "app-price-set": pricedApp()
        case "app-price-change": pricedApp(opens: .price)
        case "app-availability-edit": pricedApp(opens: .availability)
        case "app-price-error": pricedApp(services: DebugAppPriceAvailabilityServices(error: .server(statusCode: 500, detail: nil)))
        default: nil
        }
    }

    /// Quiet Timer: nothing set up.
    @MainActor
    private static func newApp(opens: AppPriceDebugSheet? = nil, pendingChanges: [PendingChange] = DebugWorkspace.pendingChanges) -> AnyView {
        var services = WorkspaceServices.debug
        services.appPriceAvailability = DebugAppPriceAvailabilityServices(opens: opens)
        return AnyView(DebugMainScene(
            services: services,
            selectedAppID: AppIDs.quiet,
            section: .subscriptionPricing,
            pendingChanges: pendingChanges,
            pricingModes: DebugWorkspace.pricingModes.merging([AppIDs.quiet: .showSuggestions]) { $1 }
        ))
    }

    /// Tempo Metronome on the Prices page's cards.
    @MainActor
    private static func pricedApp(opens: AppPriceDebugSheet? = nil, services appServices: DebugAppPriceAvailabilityServices? = nil) -> AnyView {
        var services = WorkspaceServices.debug
        var appPrice = appServices ?? DebugAppPriceAvailabilityServices()
        appPrice.opens = opens
        services.appPriceAvailability = appPrice
        services.pricing = DebugPricingServices(launch: PricingDebugLaunch(showsProducts: true))
        return AnyView(DebugMainScene(services: services, selectedAppID: AppIDs.tempo, section: .subscriptionPricing))
    }

    /// Quiet Timer's $2.99 and availability everywhere, queued by hand.
    @MainActor
    private static func queuedChanges() -> [PendingChange] {
        guard let app = DebugFixtures.apps.first(where: { $0.id == AppIDs.quiet }) else { return DebugWorkspace.pendingChanges }
        let ladder = DebugAppPriceAvailabilityServices.ladder(territoryID: "USA")
        let point = ladder.points.first { $0.customerPrice == Decimal(string: "2.99") } ?? ladder.points[0]
        let price = AppPriceChangeBuilder(app: app).change(point: point, in: .unitedStates, replacing: .notSet)
        let ids = TerritoryCatalog.standard.territories.map(\.id)
        let setup = AppAvailabilityChangeBuilder(app: app).setupChange(.everywhere(ids))
        return DebugWorkspace.pendingChanges + [price, setup]
    }
}
#endif
