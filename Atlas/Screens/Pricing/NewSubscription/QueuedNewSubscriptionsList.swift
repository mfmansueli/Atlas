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
                if PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) == nil {
                    missingReviewScreenshot(change)
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
                if IntroductoryOfferChangeBuilder.offer(in: change) == nil {
                    Button("Add Introductory Offer…", systemImage: "plus") { viewModel.openIntroductoryOffer(forQueued: change) }
                } else {
                    Button("Change Introductory Offer…", systemImage: "pencil") { viewModel.openIntroductoryOffer(forQueued: change) }
                }
            }
            if let subscription = viewModel.offerSubscription(forQueued: change) {
                Button("Add Promotional Offer…", systemImage: "plus") { viewModel.open(.newPromotional(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newPromotional")
                Button("Add Win-Back Offer…", systemImage: "plus") { viewModel.open(.newWinBack(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newWinBack")
                Button("Add Offer Code…", systemImage: "plus") { viewModel.open(.newOfferCode(subscription)) }
                    .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).newOfferCode")
                Divider()
            }
            if PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) == nil {
                Button("Add Review Screenshot…", systemImage: "plus") { viewModel.openReviewScreenshot(forQueued: change) }
            } else {
                Button("Replace Review Screenshot…", systemImage: "arrow.triangle.2.circlepath") { viewModel.openReviewScreenshot(forQueued: change) }
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

    /// App Review needs the purchase screen: until a screenshot waits with
    /// it, the product stays in Missing Metadata after the push.
    private func missingReviewScreenshot(_ change: PendingChange) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                missingReviewScreenshotText
                missingReviewScreenshotButton(change)
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                missingReviewScreenshotText
                missingReviewScreenshotButton(change)
            }
        }
        .padding(.top, Spacing.xxSmall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).reviewScreenshotMissing")
    }

    private var missingReviewScreenshotText: some View {
        Label {
            Text(String(localized: "Review screenshot missing. App Review needs one of the purchase screen.", comment: "kind:label"))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: StatusSymbol.needsYou.symbol)
                .foregroundStyle(Palette.warn)
        }
        .atlasTextStyle(.subheadline)
        .foregroundStyle(Palette.label2)
    }

    private func missingReviewScreenshotButton(_ change: PendingChange) -> some View {
        Button(String(localized: "Review Screenshot…", comment: "kind:button")) {
            viewModel.openReviewScreenshot(forQueued: change)
        }
        .secondaryButton()
        .controlSize(.small)
        .fixedSize()
        .accessibilityIdentifier("pricing.newSubscriptions.\(change.id).reviewScreenshot")
    }

    private func productID(of change: PendingChange) -> String {
        NewSubscriptionChangeBuilder.productID(of: change) ?? NewInAppPurchaseChangeBuilder.productID(of: change) ?? ""
    }
}
