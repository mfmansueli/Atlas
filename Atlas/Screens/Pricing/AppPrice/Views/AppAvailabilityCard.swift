//
//  AppAvailabilityCard.swift
//  Atlas
//

import SwiftUI

/// Where the app is sold, on Pricing's Prices page: how many countries and
/// regions, new ones, pre-order and Edit Countries and Regions…, or, for an
/// app without an availability, App Store Connect's "Determine where your
/// app will be available" with Set Up Availability….
struct AppAvailabilityCard: View {
    @Bindable var model: AppPriceAvailabilityModel
    /// As tall as App Price beside it, the link at the bottom.
    var fillsHeight = false

    var body: some View {
        AppSaleCard(
            title: String(localized: "Availability"),
            caption: String(localized: "The countries and regions \(model.app.name) is sold in."),
            figure: figure,
            figureCaption: figure == nil ? nil : String(localized: "countries or regions"),
            isQueued: model.queuedSetup != nil || model.queuedTerritoryCount > 0,
            fillsHeight: fillsHeight,
            identifier: "pricing.availability"
        ) {
            content
        }
    }

    /// "170 of 175".
    private var figure: String? {
        if let setup = model.queuedSetupValue { return String(localized: "\(setup.availableCount) of \(setup.allTerritoryIDs.count)") }
        guard let availability = model.availability.value?.availability else { return nil }
        return String(localized: "\(model.shownAvailableCount) of \(availability.territories.count)")
    }

    @ViewBuilder
    private var content: some View {
        switch model.availability {
        case .idle, .loading:
            HStack(spacing: Spacing.small) {
                ProgressView().controlSize(.small)
                Text("Reading where it’s sold…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
        case let .failed(message):
            InlineMessage.error(message)
            Button("Try Again") { Task { await model.loadAvailability() } }
                .controlSize(.regular)
                .accessibilityIdentifier("pricing.availability.tryAgain")
        case let .loaded(state):
            loaded(state)
        }
    }

    @ViewBuilder
    private func loaded(_ state: AppAvailabilityState) -> some View {
        if let availability = state.availability {
            details(availability)
        } else if let queued = model.queuedSetup {
            AppSaleQueuedBox(
                text: String(localized: "Waiting in Review & Push: \(queued.newValue)."),
                problem: queued.blockedReason,
                identifier: "pricing.availability.queued",
                onChange: { model.isAvailabilitySheetPresented = true },
                onDiscard: model.discardQueuedSetup,
                onReview: model.onOpenReview
            )
        } else {
            Text("Choose where \(model.app.name) will be available. It can be offered for pre-order before its release.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Set Up Availability…") { model.isAvailabilitySheetPresented = true }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("pricing.availability.setUp")
        }
    }

    @ViewBuilder
    private func details(_ availability: AppAvailability) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(newTerritoriesText(availability))
            if let releaseDate = availability.preOrderReleaseDate {
                Text("Offered for pre-order until its release on \(releaseDate).")
            }
            if model.queuedTerritoryCount > 0 {
                Text("\(model.queuedTerritoryCount) countries or regions change in Review & Push.")
                    .foregroundStyle(Palette.accentText)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.label2)
        if fillsHeight {
            Spacer(minLength: 0)
        }
        HStack {
            if model.queuedTerritoryCount > 0 {
                Button("Review & Push…", action: model.onOpenReview)
                    .buttonStyle(.link)
                    .controlSize(.regular)
            }
            Spacer()
            Button("Edit Countries and Regions…") { model.isAvailabilitySheetPresented = true }
                .buttonStyle(.link)
                .controlSize(.regular)
                .accessibilityIdentifier("pricing.availability.edit")
        }
    }

    private func newTerritoriesText(_ availability: AppAvailability) -> String {
        switch availability.availableInNewTerritories {
        case true?: String(localized: "New countries and regions get it automatically.")
        case false?: String(localized: "New countries and regions don’t get it until you add them.")
        case nil: String(localized: "Sold where App Store Connect lists it.")
        }
    }
}
