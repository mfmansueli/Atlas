//
//  PricesByCountryView.swift
//  Atlas
//

import SwiftUI

/// A product's Prices by Country (board 73): the page's one banner with the
/// open suggestion and the strategy, Find, the segments, Filters, Columns
/// and Table · Map · Histogram, then every country's price, and the line
/// of totals with when price changes start. Clicking a price opens its
/// popover; every change waits in Review & Push as one row per product,
/// with a toast that can take it back.
struct PricesByCountryView: View {
    let viewModel: PricingViewModel
    let productID: PricingProduct.ID
    @Binding var filter: PricesByCountryFilter
    /// A country (alpha-3) to select and scroll to, e.g. from the product's
    /// card or the assistant.
    @Binding var focusedTerritory: String?

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .onChange(of: productID, initial: true) { viewModel.pricesByCountry.show(productID: productID) }
        .task(id: productID) {
            if viewModel.countriesMatrix(productID: productID) == nil, viewModel.productsTask == nil {
                await viewModel.retryProduct(productID: productID)
            }
            // The person is looking: Apple's price points are read now.
            await viewModel.loadPageGrid(productID: productID)
        }
        .sheet(isPresented: acceptAllPresented) { acceptAllSheet }
        .modifier(PriceTestSheetsModifier(viewModel: viewModel))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries")
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if let rows = viewModel.countryRows(productID: productID) {
            loaded(rows, size: size)
        } else if let error = viewModel.countriesError(productID: productID) {
            failed(error)
        } else {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                PricesByCountryToolbar(search: .constant(""), filter: $filter, counts: [:], state: viewModel.pricesByCountry)
                    .disabled(true)
                PricesByCountrySkeleton()
            }
        }
    }

    private func loaded(_ rows: [CountryPriceRow], size: CGSize) -> some View {
        @Bindable var state = viewModel.pricesByCountry
        let visible = PricesByCountryQuery.visible(rows, filter: filter, filters: state.filters, search: state.search, sortOrder: state.sortOrder)
        let counts = PricesByCountryQuery.counts(rows, filters: state.filters, search: state.search)
        let isShort = size.height < Metrics.countriesShortHeight
        let isNarrow = size.width < Metrics.countriesNarrowWidth
        let isCompact = state.isCompact
        let suggestion = viewModel.countriesSuggestion(productID: productID)
        return VStack(alignment: .leading, spacing: isCompact ? Spacing.small : Spacing.medium) {
            priceTestStatus
            if let grid = viewModel.countriesGrid(productID: productID), !grid.isReady {
                // No suggestion stands on a simulated ladder.
                PricesByCountryGridStatus(state: grid) {
                    Task { await viewModel.retryGrid(productID: productID) }
                }
            } else if let suggestion {
                PricesByCountrySuggestionBanner(
                    viewModel: viewModel,
                    suggestion: suggestion,
                    productName: viewModel.countriesProduct(productID: productID)?.name ?? "",
                    howSure: viewModel.countriesHowSure(productID: productID),
                    baseline: viewModel.countriesBaseline(productID: productID),
                    isFree: pro.isFree,
                    isCompact: isCompact,
                    onDismissAll: { viewModel.dismissPriceSuggestion(productID: productID) },
                    onAcceptAll: { state.isAcceptAllPresented = true }
                )
            } else if let match = viewModel.countriesMatchLine(productID: productID) {
                // No suggestion to make: no banner, the summary line
                // (README-DS §10), grey since nothing waits (board 76).
                Text(match)
                    .atlasTextStyle(.headline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(Text(verbatim: match))
                    .accessibilityIdentifier("countries.summary")
            }
            PricesByCountryToolbar(
                search: $state.search,
                filter: $filter,
                counts: counts,
                state: state,
                isCompact: isCompact,
                showsColumns: !isNarrow,
                // At 860 × 560 the banner keeps one line, so the strategy
                // pop-up waits here instead.
                strategy: (suggestion == nil || isCompact) && viewModel.countriesProduct(productID: productID)?.isInAppPurchase == false
                    ? AnyView(PricesByCountryStrategyMenu(viewModel: viewModel))
                    : nil
            )
            if state.filters.isActive {
                PricesByCountryFilterLine(text: filterLine(rows, shown: visible.count)) { state.clearFilters() }
            }
            VStack(spacing: 0) {
                if visible.isEmpty {
                    empty(PricesByCountryEmptyText.make(filter: filter, search: state.search))
                } else {
                    switch state.display {
                    case .table:
                        table(visible, isNarrow: isNarrow, isShort: isShort)
                    case .map:
                        CountryPriceMapView(viewModel: viewModel, productID: productID, rows: visible)
                            .padding(.top, Spacing.xxSmall)
                    case .histogram:
                        CountryPriceHistogramView(histogram: viewModel.countriesHistogram(productID: productID, rows: visible))
                            .padding(.top, Spacing.small)
                    }
                }
                if !state.selection.isEmpty, state.display == .table {
                    bulkBar(rows)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            if let totals = viewModel.countriesTotals(productID: productID) {
                PricesByCountryFooter(
                    totals: totals,
                    schedule: viewModel.countriesSchedule(productID: productID),
                    canSchedule: viewModel.countriesCanSchedule(productID: productID),
                    onRightAway: { viewModel.startCountryChangesRightAway(productID: productID) },
                    onDate: { viewModel.scheduleCountryChanges(productID: productID) }
                )
                .padding(.bottom, Spacing.xSmall)
            }
        }
    }

    /// A running price test (board 76): a line, not a banner.
    @ViewBuilder
    private var priceTestStatus: some View {
        if let line = viewModel.priceTestStatusLine(productID: productID) {
            PriceTestStatusLine(text: line) { viewModel.showPriceTest(productID: productID) }
        }
    }

    /// "Europe · Increases only · 2 of 40 shown": of the countries the
    /// segment, Find and the regions keep.
    private func filterLine(_ rows: [CountryPriceRow], shown: Int) -> String {
        let state = viewModel.pricesByCountry
        var regionsOnly = PricesByCountryFilters()
        regionsOnly.regions = state.filters.regions
        let total = PricesByCountryQuery.visible(rows, filter: filter, filters: regionsOnly, search: state.search, sortOrder: []).count
        return state.filters.line(shown: shown, of: total)
    }

    private func table(_ rows: [CountryPriceRow], isNarrow: Bool, isShort: Bool) -> some View {
        ScrollViewReader { proxy in
            PricesByCountryTable(
                viewModel: viewModel,
                productID: productID,
                rows: rows,
                isNarrow: isNarrow,
                opensPopoverAtTop: isShort,
                onAccept: accept
            )
            .overlay(alignment: .top) {
                if isShort { topPopoverAnchor }
            }
            .onChange(of: focusedTerritory, initial: true) {
                guard let id = focusedTerritory, rows.contains(where: { $0.id == id }) else { return }
                viewModel.pricesByCountry.selection = [id]
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    /// In a table shorter than 420 pt, the popover opens from its top and
    /// scrolls in what's left.
    private var topPopoverAnchor: some View {
        Color.clear
            .frame(height: 1)
            .popover(isPresented: topPopoverPresented, arrowEdge: .top) {
                if let choice = viewModel.pricesByCountry.popover,
                   let row = viewModel.countryRow(productID: productID, territoryID: choice.territoryID)
                {
                    CountryPricePopover(
                        viewModel: viewModel,
                        productID: productID,
                        row: row,
                        choice: Binding { viewModel.pricesByCountry.popover ?? choice } set: { viewModel.pricesByCountry.popover = $0 },
                        listHeight: Metrics.countriesPointListMinimumHeight,
                        scrolls: true
                    )
                }
            }
            .accessibilityHidden(true)
    }

    private var topPopoverPresented: Binding<Bool> {
        Binding {
            viewModel.pricesByCountry.popover != nil
        } set: { isPresented in
            if !isPresented { viewModel.pricesByCountry.popover = nil }
        }
    }

    private var acceptAllPresented: Binding<Bool> {
        Binding {
            viewModel.pricesByCountry.isAcceptAllPresented && viewModel.pricesByCountry.productID == productID
        } set: { viewModel.pricesByCountry.isAcceptAllPresented = $0 }
    }

    private var acceptAllSheet: some View {
        AcceptAllPricesSheet(
            plan: viewModel.acceptAllPlan(productID: productID),
            productName: viewModel.countriesProduct(productID: productID)?.name ?? "",
            canSchedule: viewModel.countriesCanSchedule(productID: productID),
            schedule: viewModel.countriesSchedule(productID: productID),
            priceTestLine: viewModel.priceTestAcceptAllLine(productID: productID),
            onCancel: { viewModel.pricesByCountry.isAcceptAllPresented = false },
            onAdd: { schedule in
                let count = viewModel.acceptAllPlan(productID: productID).count
                let accept = { _ = Task.immediate { await viewModel.acceptAllCountrySuggestions(productID: productID, schedule: schedule) } }
                if count > 1 { pro.require(.recommendedPrices(countries: count), then: accept) } else { accept() }
            }
        )
    }

    private func bulkBar(_ rows: [CountryPriceRow]) -> some View {
        let selection = viewModel.pricesByCountry.selection
        let selected = rows.filter { selection.contains($0.id) }
        let suggested = selected.count(where: \.hasSuggestion)
        return PricesByCountryBulkBar(
            selectedCount: selected.count,
            suggestedCount: suggested,
            automaticCount: selected.count(where: PricingViewModel.canGoAutomatic),
            isFree: pro.isFree,
            onAccept: {
                let accept = { _ = Task.immediate { await viewModel.acceptCountrySuggestions(productID: productID, territoryIDs: selection) } }
                if suggested > 1 { pro.require(.recommendedPrices(countries: suggested), then: accept) } else { accept() }
            },
            onAutomatic: { Task { await viewModel.setCountriesToAutomatic(productID: productID, territoryIDs: selection) } },
            onDeselect: { viewModel.pricesByCountry.selection = [] }
        )
    }

    @ViewBuilder
    private func empty(_ empty: PricesByCountryEmptyText) -> some View {
        if empty.query != nil {
            // Find matched nothing (board 74): the inline empty state.
            EmptyStateView(
                empty.text,
                systemImage: empty.symbol,
                text: String(localized: "Find looks in names, ISO codes, currencies and regions.", comment: "kind:empty-state"),
                size: .inline
            ) {
                Button(String(localized: "Clear Search", comment: "kind:button")) { viewModel.pricesByCountry.search = "" }
                    .secondaryButton()
                    .accessibilityIdentifier("countries.empty.clearSearch")
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("countries.empty")
        } else {
            filterEmpty(empty)
        }
    }

    private func filterEmpty(_ empty: PricesByCountryEmptyText) -> some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: empty.symbol)
                .atlasTextStyle(.title2)
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text(empty.text)
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.pricesByCountry.filters.isActive {
                Button(String(localized: "Clear Filters", comment: "kind:button")) { viewModel.pricesByCountry.clearFilters() }
                    .secondaryButton()
                    .accessibilityIdentifier("countries.empty.clearFilters")
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.empty")
    }

    private func failed(_ message: String) -> some View {
        ContentUnavailableView {
            Label(String(localized: "Prices Didn’t Load", comment: "kind:error"), systemImage: "exclamationmark.triangle")
                .foregroundStyle(Palette.warn)
        } description: {
            Text(message)
        } actions: {
            Button(String(localized: "Try Again", comment: "kind:button")) {
                Task { await viewModel.retryProduct(productID: productID) }
            }
            .secondaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("countries.error")
    }

    private func accept(_ row: CountryPriceRow) {
        Task { await viewModel.acceptCountrySuggestion(productID: productID, territoryID: row.id) }
    }
}
