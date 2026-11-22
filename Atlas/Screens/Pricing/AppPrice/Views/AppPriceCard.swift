//
//  AppPriceCard.swift
//  Atlas
//

import SwiftUI

/// The app's own price on Pricing's Prices page: today's price in the base
/// country or region with its proceeds and Change Price…, or, for an app
/// without one, App Store Connect's "Set up a starting price" with Add
/// Pricing…. A price waiting in Review & Push shows what it sets.
struct AppPriceCard: View {
    @Bindable var model: AppPriceAvailabilityModel

    var body: some View {
        AppSaleCard(
            title: String(localized: "App Price"),
            caption: String(localized: "What \(model.app.name) costs to download."),
            figure: current?.formattedPrice,
            figureCaption: current.map { String(localized: "\(AppTerritory.name(of: $0.baseTerritoryID)) · base") },
            isQueued: model.queuedPrice != nil,
            identifier: "pricing.appPrice"
        ) {
            content
        }
    }

    private var current: AppCurrentPrice? {
        model.price.value?.current
    }

    @ViewBuilder
    private var content: some View {
        switch model.price {
        case .idle, .loading:
            HStack(spacing: Spacing.small) {
                ProgressView().controlSize(.small)
                Text("Reading the price…")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
        case let .failed(message):
            InlineMessage.error(message)
            Button("Try Again") { Task { await model.loadPrice() } }
                .controlSize(.small)
                .accessibilityIdentifier("pricing.appPrice.tryAgain")
        case let .loaded(state):
            loaded(state)
        }
    }

    @ViewBuilder
    private func loaded(_ state: AppPriceState) -> some View {
        if let queued = model.queuedPrice {
            AppSaleQueuedBox(
                text: String(localized: "Waiting in Review & Push: \(queued.newValue)."),
                problem: queued.blockedReason,
                identifier: "pricing.appPrice.queued",
                onChange: { model.isPriceSheetPresented = true },
                onDiscard: model.discardQueuedPrice,
                onReview: model.onOpenReview
            )
        } else if let current = state.current {
            details(current)
        } else {
            Text("Set up a starting price for \(model.app.name). Every other country or region gets Apple’s equalized price.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add Pricing…") { model.isPriceSheetPresented = true }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("pricing.appPrice.add")
        }
    }

    @ViewBuilder
    private func details(_ current: AppCurrentPrice) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            if let point = current.point {
                Text(point.customerPrice == 0
                    ? String(localized: "Free in every country or region.")
                    : String(localized: "\(AppPriceText.proceeds(point.proceeds, currencyCode: current.currencyCode)) · Apple equalizes it everywhere else."))
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            if !current.otherManualTerritoryIDs.isEmpty {
                Text("Set by hand in \(current.otherManualTerritoryIDs.count) other countries or regions.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            if current.laterChangeCount > 0 {
                Text("\(current.laterChangeCount) price changes scheduled.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
        }
        // At the bottom when the card is as tall as Availability.
        Spacer(minLength: 0)
        HStack {
            Spacer()
            Button("Change Price…") { model.isPriceSheetPresented = true }
                .buttonStyle(.link)
                .controlSize(.small)
                .accessibilityIdentifier("pricing.appPrice.change")
        }
    }
}
