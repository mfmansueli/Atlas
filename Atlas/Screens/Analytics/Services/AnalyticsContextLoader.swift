//
//  AnalyticsContextLoader.swift
//  Atlas
//

import Foundation

/// Reads what the other sections know (the page's languages and how they
/// were translated, the main subscription's prices, the retention
/// messages) so Analytics can name a likely cause. Each part is read on
/// its own, and a part that fails is left out.
@MainActor
struct AnalyticsContextLoader {
    let services: WorkspaceServices
    var machineTranslations: any MachineTranslationStore = FileMachineTranslationStore.shared
    var commission: Commission = .smallBusiness

    /// The store page's part, which is quick.
    func storePage(for app: StoreApp) async -> AnalyticsContext {
        var context = AnalyticsContext()
        guard let content = try? await services.storePage.content(for: app, versionID: nil) else { return context }
        context.primaryLocale = content.primaryLocale
        context.pageLocales = content.locales
        let tags = MachineTranslationScope.tags(in: machineTranslations, appID: app.id, ids: content.ids)
        for locale in content.locales {
            let texts = (content.texts[locale] ?? [:]).filter { !$0.value.isEmpty }
            let tagged = texts.count { field, value in tags[ListingFieldKey(locale, field).id] == value }
            // Mostly machine-translated: more than half of what it says.
            if !texts.isEmpty, tagged * 2 > texts.count { context.machineTranslated.insert(locale.code) }
        }
        return context
    }

    /// Adds prices against purchasing power and the live retention
    /// messages; several requests, so it runs after the funnel shows.
    func pricing(for app: StoreApp, into context: AnalyticsContext) async -> AnalyticsContext {
        var context = context
        guard let catalog = try? await services.pricing.catalog(for: app), let product = catalog.subscriptions.first else { return context }
        if let sheet = try? await services.pricing.priceSheet(for: product, commission: commission) {
            let calculator = PriceCalculator(catalog: .standard, snapshot: services.pricing.indexSnapshot(), commission: commission)
            let rows = PricingRowBuilder(catalog: .standard, calculator: calculator, sheet: sheet, strategy: .recommended, showsSuggestions: true).rows()
            for row in rows {
                guard let suggested = row.recommendation?.price.customerPrice, suggested > 0 else { continue }
                let ratio = NSDecimalNumber(decimal: row.current.customerPrice / suggested).doubleValue
                context.prices[row.territory.alpha2] = TerritoryPriceContext(
                    priceText: row.currency.format(row.current.customerPrice),
                    suggestedText: row.currency.format(suggested),
                    ratio: ratio,
                    productName: product.name
                )
            }
        }
        let subscriptions = RetentionSubscription.all(in: catalog)
        if !subscriptions.isEmpty, let retention = try? await services.retention.content(for: app, subscriptions: subscriptions) {
            context.liveRetentionMessages = retention.messages.count { $0.remote?.status == .live }
        }
        return context
    }
}
