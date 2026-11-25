//
//  RetentionScreen.swift
//  Atlas
//

import SwiftUI

/// Pricing → Retention: the header, Apple's rules, then the messages,
/// offers and server setup on the left, the selected message in the
/// middle and Apple's Confirm Cancellation screen on the right; or, before
/// there's a message, how to start one.
struct RetentionScreen: View {
    let model: RetentionModel
    @Bindable var pricing: PricingViewModel
    /// Analytics' last 28 complete days of Retention Messaging; nil before
    /// Apple's report arrives.
    var saveRates: RetentionReport?
    var onOpenAnalytics: () -> Void = {}

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                RetentionHeader(model: model, page: $pricing.page)
                RetentionIntroBanner()
                if let saveRates {
                    RetentionSaveRatesBanner(report: saveRates, onOpen: onOpenAnalytics)
                }
                content
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.large)
        }
        .leavesChatRoom()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: pricing.catalog?.groups.count) { await load(force: false) }
        .sheet(isPresented: $model.isOfferSheetPresented) {
            if let draft = model.newOfferDraft() {
                RetentionOfferSheet(
                    subscriptions: model.subscriptions,
                    initial: draft,
                    problems: model.offerProblems,
                    onCancel: { model.isOfferSheetPresented = false },
                    onAdd: { model.addOffer($0) }
                )
            }
        }
        .sheet(isPresented: $model.isImageSheetPresented) {
            RetentionImageSheet(model: model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.retention")
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .idle, .loading:
            HStack(spacing: Spacing.small) {
                ProgressView().controlSize(.small)
                Text("Reading retention messages…")
                    .foregroundStyle(Palette.label2)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            Card {
                Text("Atlas couldn’t read the retention messages")
                    .font(.body.weight(.semibold))
                Text(message)
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
                Button("Try Again") { Task { await load(force: true) } }
            }
        case .loaded:
            if let message = model.selectedMessage {
                RetentionColumnsLayout {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        RetentionMessagesBox(model: model, saveRates: saveRates)
                        if let saveRates, !saveRates.isEmpty {
                            RetentionSaveRatesBox(report: saveRates)
                        }
                        RetentionOffersBox(model: model)
                        RetentionServerBox(model: model)
                    }
                    RetentionEditor(model: model, message: message)
                    RetentionPreview(model: model, message: message)
                }
            } else {
                RetentionEmptyState(model: model)
            }
        }
    }

    private func load(force: Bool) async {
        guard let catalog = pricing.catalog else { return }
        await model.load(subscriptions: RetentionSubscription.all(in: catalog), force: force)
    }
}
