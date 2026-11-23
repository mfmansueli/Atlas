//
//  QueuedNewSubscriptionsList.swift
//  Atlas
//

import SwiftUI

/// The new subscriptions and in-app purchases waiting in Review & Push,
/// each with its product ID, duration or type and price, who proposed it,
/// the offers waiting with it, a menu that adds an introductory offer,
/// promotional offer, win-back offer or offer code (subscriptions) or the
/// review screenshot, and Discard (its offers go with it). They're pushed
/// from the toolbar's Review & Push (board 57).
struct QueuedNewSubscriptionsList: View {
    @Bindable var viewModel: PricingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Waiting in Review & Push")
                .font(.body.weight(.semibold))
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.queuedNewProducts.enumerated()), id: \.element.id) { index, change in
                        if index > 0 { Divider() }
                        row(change)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.newSubscriptions")
    }

    private func row(_ change: PendingChange) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.title)
                    .fontWeight(.medium)
                Text(productID(of: change))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.label2)
                ForEach(viewModel.waitingOffers(forQueued: change)) { offer in
                    Text("\(offer.title) · \(offer.newValue)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).offer.\(offer.id)")
                }
                if let blocked = change.blockedReason {
                    Text(blocked)
                        .font(.subheadline)
                        .foregroundStyle(Palette.err)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.small)
            VStack(alignment: .trailing, spacing: 2) {
                Text(change.newValue)
                    .monospacedDigit()
                Text(change.source.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            setupMenu(change)
            Button {
                viewModel.discardNewSubscription(id: change.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Palette.label3)
            }
            .buttonStyle(.plain)
            .help(Text("Discard"))
            .accessibilityLabel(Text("Discard \(change.title)"))
            .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).discard")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.newSubscriptions.\(change.id)")
    }

    /// Add Introductory Offer… (a subscription without one) and Review
    /// Screenshot…, as more steps of the queued change, and a promotional
    /// offer, win-back offer or offer code, each its own change that waits
    /// for it.
    private func setupMenu(_ change: PendingChange) -> some View {
        Menu {
            if NewSubscriptionChangeBuilder.owns(change) {
                Button(IntroductoryOfferChangeBuilder.offer(in: change) == nil ? "Add Introductory Offer…" : "Change Introductory Offer…") {
                    viewModel.openIntroductoryOffer(forQueued: change)
                }
            }
            if let subscription = viewModel.offerSubscription(forQueued: change) {
                Button("Add Promotional Offer…") { viewModel.open(.newPromotional(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newPromotional")
                Button("Add Win-Back Offer…") { viewModel.open(.newWinBack(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newWinBack")
                Button("Add Offer Code…") { viewModel.open(.newOfferCode(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newOfferCode")
                Divider()
            }
            Button(PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) == nil ? "Add Review Screenshot…" : "Replace Review Screenshot…") {
                viewModel.openReviewScreenshot(forQueued: change)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Palette.label2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("Set it up"))
        .accessibilityLabel(Text("Set up \(change.title)"))
        .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).setup")
    }

    private func productID(of change: PendingChange) -> String {
        NewSubscriptionChangeBuilder.productID(of: change) ?? NewInAppPurchaseChangeBuilder.productID(of: change) ?? ""
    }
}
