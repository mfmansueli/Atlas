//
//  NoSubscriptionsView.swift
//  Atlas
//

import SwiftUI

/// What Pricing shows for an app that sells nothing yet (board 74, README-DS
/// §14): Add Subscription… in the toolbar as on every Pricing page (board
/// 80), no Prices | Retention, then the empty state with the assistant's Ask,
/// Add In-App Purchase… and the new subscriptions and in-app purchases
/// already waiting in Review & Push.
struct NoSubscriptionsView: View {
    @Bindable var viewModel: PricingViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(subtitle: String(localized: "What \(viewModel.app.name) costs, in each country and region.", comment: "kind:description")) {}
                .padding(.horizontal, Spacing.xLarge)
                .padding(.top, Spacing.large)
            if let appPriceAvailability = viewModel.appPriceAvailability {
                // A new app has no price or availability either: they come
                // first, as on App Store Connect's Pricing and Availability.
                AppPriceAvailabilityCards(model: appPriceAvailability)
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.top, Spacing.large)
            }
            // The queued list goes in the actions: a fixed-size empty state
            // above it made the window's minimum height follow the text's
            // wrapping, and AppKit's layout looped until it crashed.
            EmptyStateView(
                String(localized: "Nothing for sale yet", comment: "kind:empty-state"),
                systemImage: "tag",
                text: text
            ) {
                VStack(spacing: Spacing.xLarge) {
                    HStack(spacing: Spacing.small) {
                        NewSubscriptionAskButton(app: viewModel.app)
                        Button(String(localized: "Add In-App Purchase…", comment: "kind:button")) {
                            viewModel.setup.isNewInAppPurchaseSheetPresented = true
                        }
                        .secondaryButton()
                        .accessibilityIdentifier("pricing.createInAppPurchase")
                    }
                    // The actions are only about 360 pt wide, which cut the
                    // titles off; the buttons' own width is fixed, so this
                    // can't loop like the whole view's size did.
                    .fixedSize(horizontal: true, vertical: false)
                    if !viewModel.queuedNewProducts.isEmpty {
                        QueuedNewSubscriptionsList(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.noSubscriptions")
    }

    private var text: String {
        viewModel.queuedNewProducts.isEmpty
            ? String(
                localized: "Subscriptions and in-app purchases show here, priced in every country. Use Add Subscription… or ask your assistant.",
                comment: "kind:empty-state"
            )
            : String(localized: "Push to create them, then refresh to set their prices here.", comment: "kind:empty")
    }
}
