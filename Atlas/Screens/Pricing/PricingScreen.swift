//
//  PricingScreen.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// Subscription Pricing laid out: a card per product, or one product's page
/// (board 73), with the strategy inspector (floating over the page at
/// 860 × 560), the mode and schedule sheets, the custom index import and the
/// Accept toast around them.
struct PricingScreen: View {
    @Bindable var viewModel: PricingViewModel
    /// Preselected in the first-visit sheet: the default for new apps from Settings.
    let defaultMode: PricingMode

    @State private var isImporterPresented = false
    /// Recommended prices for many countries are Pro's; nil in previews.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        @Bindable var strategy = viewModel.strategy
        VStack(spacing: 0) {
            if let catalog = viewModel.catalog, catalog.isEmpty {
                NoSubscriptionsView(viewModel: viewModel)
            } else if let message = viewModel.catalogState.errorMessage {
                failure(message)
            } else if let product = viewModel.pageProduct {
                // A product's page (board 73) in place of the cards.
                PricingProductPage(viewModel: viewModel, product: product)
            } else {
                PricingProductsView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            // A strategy an assistant suggested waits above the prices.
            if let suggestion = viewModel.strategySuggestion, viewModel.catalog?.isEmpty == false {
                PricingStrategySuggestionCard(
                    suggestion: suggestion,
                    comparison: viewModel.strategyComparison(for: suggestion),
                    onDismiss: viewModel.dismissStrategySuggestion,
                    onAccept: { Task { await viewModel.acceptStrategySuggestion() } }
                )
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.small)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ActionToast(message: toast) {
                    viewModel.undoToast()
                } onAction: {
                    viewModel.toast = nil
                    viewModel.onOpenReview()
                } onDismiss: {
                    if viewModel.toast == toast { viewModel.toast = nil }
                }
                .padding(.bottom, Spacing.large)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.toast)
        .overlay(alignment: .topTrailing) {
            // At 860 × 560 the inspector floats over the table.
            if viewModel.isInspectorPresented, isInspectorFloating {
                StrategyInspector(viewModel: viewModel, isFloating: true) { isImporterPresented = true }
                    .frame(width: Metrics.inspectorWidth)
                    .frame(maxHeight: .infinity)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
                    .padding(Spacing.medium)
                    .accessibilityIdentifier("pricing.inspector.floating")
            }
        }
        .inspector(isPresented: dockedInspector) {
            StrategyInspector(viewModel: viewModel) { isImporterPresented = true }
        }
        .sheet(isPresented: $viewModel.isModeSheetPresented) {
            PricingModeSheet(
                appName: viewModel.app.name,
                initialMode: defaultMode,
                onContinue: { mode in Task { await viewModel.choose(mode) } },
                onNotNow: viewModel.notNow
            )
        }
        .sheet(isPresented: $viewModel.isNewSubscriptionSheetPresented) {
            NewSubscriptionSheet(
                appID: viewModel.app.id,
                appName: viewModel.app.name,
                bundleID: viewModel.app.bundleID,
                groups: viewModel.subscriptionGroups,
                initial: newSubscriptionDefaults,
                problems: viewModel.problems(for:),
                onCancel: { viewModel.isNewSubscriptionSheetPresented = false },
                onAdd: addNewSubscription,
                recommend: viewModel.recommendation(forPrice:),
                isFree: pro.isFree
            )
        }
        .sheet(isPresented: isReviewingLater) {
            if let productID = viewModel.reviewLaterProductID, let product = viewModel.catalog?.product(id: productID) {
                RecommendedPricesReviewSheet(
                    productName: product.name,
                    places: viewModel.reviewLaterPlaces(productID: productID),
                    onApply: { applyRecommendations($0, productID: productID) },
                    onKeep: { viewModel.keepApplePrices(productID: productID) },
                    onLater: { viewModel.reviewLaterProductID = nil }
                )
                .pageControlSize()
            }
        }
        .modifier(PurchaseSetupSheets(viewModel: viewModel))
        .sheet(isPresented: $viewModel.isStartingPriceSheetPresented) {
            StartingPriceSheet(
                productName: viewModel.selectedProduct?.name ?? "",
                initialPrice: nil,
                onCancel: { viewModel.isStartingPriceSheetPresented = false },
                onSave: viewModel.queueStartingPrice
            )
        }
        .sheet(isPresented: $viewModel.isScheduleSheetPresented) {
            if let matrix = viewModel.matrix {
                PriceScheduleSheet(
                    productName: matrix.product.name,
                    schedule: matrix.schedule,
                    consent: matrix.increaseConsent(subscribers: viewModel.subscribers),
                    today: viewModel.today(),
                    onCancel: { viewModel.isScheduleSheetPresented = false },
                    onSave: viewModel.saveSchedule
                )
            }
        }
        .sheet(item: $strategy.importPreview) { preview in
            CustomIndexImportSheet(
                preview: preview,
                territoryCount: viewModel.strategy.territories.count,
                onCancel: viewModel.strategy.cancelImport,
                onImport: viewModel.confirmImport
            )
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { result in
            importFile(result)
        }
        .confirmationDialog(
            String(localized: "Keep your prices?"),
            isPresented: $viewModel.isKeepConfirmationPresented
        ) {
            Button(String(localized: "Discard \(viewModel.pendingPriceChangeCount) Price Changes"), role: .destructive) {
                viewModel.confirmKeepPrices()
            }
        } message: {
            Text("“Keep my prices” discards the price changes for \(viewModel.app.name) waiting in Review & Push.")
        }
    }

    /// A product's page at its smallest: the inspector floats.
    private var isInspectorFloating: Bool {
        viewModel.pageProduct != nil && viewModel.pricesByCountry.isCompact
    }

    private var dockedInspector: Binding<Bool> {
        Binding {
            viewModel.isInspectorPresented && !isInspectorFloating
        } set: { viewModel.isInspectorPresented = $0 }
    }

    /// Create Subscription's defaults: the recommended prices with Pro,
    /// Apple's equalized ones in Free.
    private var newSubscriptionDefaults: NewSubscription {
        var subscription = viewModel.newSubscriptionDefaults()
        subscription.priceChoice = pro.isFree ? .equalized : .recommended
        return subscription
    }

    /// Add to Review & Push. With the recommended prices in Free, the
    /// sheet closes for the paywall, whose continue button adds it.
    private func addNewSubscription(_ subscription: NewSubscription) {
        guard subscription.priceChoice.needsPro, pro.isFree else {
            viewModel.queueNewSubscription(subscription)
            return
        }
        let countries = subscription.price.flatMap(viewModel.recommendation(forPrice:))?.changed.count ?? 0
        viewModel.isNewSubscriptionSheetPresented = false
        Task {
            // One sheet at a time: after this one has left.
            try? await Task.sleep(for: .milliseconds(350))
            pro.require(.recommendedPrices(countries: countries)) { viewModel.queueNewSubscription(subscription) }
        }
    }

    private var isReviewingLater: Binding<Bool> {
        Binding { viewModel.reviewLaterProductID != nil } set: { if !$0 { viewModel.reviewLaterProductID = nil } }
    }

    /// Apply Selected or Apply All: one country stays free; more are Pro's.
    private func applyRecommendations(_ territoryIDs: [String], productID: String) {
        let apply = { _ = Task.immediate { await viewModel.applyRecommendations(productID: productID, territoryIDs: territoryIDs) } }
        guard territoryIDs.count > 1, pro.isFree else {
            apply()
            return
        }
        viewModel.reviewLaterProductID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            pro.require(.recommendedPrices(countries: territoryIDs.count), then: apply)
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Prices couldn’t load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await viewModel.reload() } }
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("pricing.tryAgain")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func importFile(_ result: Result<URL, any Error>) {
        guard case let .success(url) = result else { return }
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            viewModel.onNotice(.apiError(String(localized: "“\(url.lastPathComponent)” couldn’t be read as text.")))
            return
        }
        let multipliers = viewModel.matrix?.sheet.prices
        viewModel.strategy.previewImport(text: text, fileName: url.lastPathComponent) { territory in
            multipliers?[territory.id]?.equalizationMultiplier
        }
    }
}
