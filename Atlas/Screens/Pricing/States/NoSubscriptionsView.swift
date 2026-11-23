//
//  NoSubscriptionsView.swift
//  Atlas
//

import SwiftUI

/// What Pricing shows for an app that sells nothing yet: Create
/// Subscription, Ask Claude Code to set up the ones the app's code sells,
/// Create an In-App Purchase, and the new subscriptions and in-app
/// purchases already waiting in Review & Push.
struct NoSubscriptionsView: View {
    @Bindable var viewModel: PricingViewModel

    @Environment(\.openURL) private var openURL

    // The queued list goes in the actions: a fixed-size ContentUnavailableView
    // above it made the window's minimum height follow the description's
    // wrapping, and AppKit's layout looped until it crashed.
    var body: some View {
        ContentUnavailableView {
            Label("\(viewModel.app.name) has no subscriptions", systemImage: "tag")
        } description: {
            Text(description)
        } actions: {
            VStack(spacing: Spacing.xLarge) {
                HStack(spacing: Spacing.small) {
                    Button("Create Subscription…") { viewModel.isNewSubscriptionSheetPresented = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("pricing.createSubscription")
                    NewSubscriptionAskButton(app: viewModel.app)
                    Button("Open App Store Connect") {
                        if let url = URL(string: "https://appstoreconnect.apple.com/apps") { openURL(url) }
                    }
                    .accessibilityIdentifier("pricing.openAppStoreConnect")
                }
                .buttonBorderShape(.capsule)
                // The actions are only about 360 pt wide, which cut the
                // titles off; the buttons' own width is fixed, so this can't
                // loop like the whole view's size did.
                .fixedSize(horizontal: true, vertical: false)
                // Its own row: a fourth button made the row wider than the view.
                Button("New In-App Purchase…") { viewModel.setup.isNewInAppPurchaseSheetPresented = true }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("pricing.createInAppPurchase")
                if !viewModel.queuedNewProducts.isEmpty {
                    QueuedNewSubscriptionsList(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: 520)
        .padding(Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.noSubscriptions")
    }

    private var description: String {
        viewModel.queuedNewProducts.isEmpty
            ? String(localized: """
            Create one here, or ask your assistant for the ones the code sells. Pushing creates them with texts, availability and starting \
            price.
            """)
            : String(localized: "Push to create them, then refresh to set their prices here.")
    }
}
