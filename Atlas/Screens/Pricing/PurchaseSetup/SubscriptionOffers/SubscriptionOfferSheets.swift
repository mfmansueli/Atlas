//
//  SubscriptionOfferSheets.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// The promotional offer, win-back offer and offer code sheets, shown from
/// `setup.offerRoute`, and Save Codes…'s save panel.
struct SubscriptionOfferSheets: ViewModifier {
    @Bindable var viewModel: PricingViewModel

    func body(content: Content) -> some View {
        @Bindable var setup = viewModel.setup
        content
            .sheet(item: $setup.offerRoute) { route in
                sheet(for: route)
            }
            .fileExporter(
                isPresented: Binding { setup.codesFile != nil } set: { if !$0 { setup.codesFile = nil } },
                document: setup.codesFile,
                contentType: .commaSeparatedText,
                defaultFilename: setup.codesFile?.fileName
            ) { _ in
                setup.codesFile = nil
            }
            .alert(
                "The codes couldn’t be saved",
                isPresented: Binding { setup.codesSaveError != nil } set: { if !$0 { setup.codesSaveError = nil } },
                actions: { Button("OK") { setup.codesSaveError = nil } },
                message: { Text(setup.codesSaveError ?? "") }
            )
    }

    @ViewBuilder
    private func sheet(for route: SubscriptionOfferRoute) -> some View {
        let close = { viewModel.closeOfferSheet() }
        switch route {
        case let .newPromotional(subscription):
            PromotionalOfferSheet(
                subscription: subscription,
                problems: { viewModel.problems(for: $0, subscription: subscription) },
                onCancel: close,
                onAdd: { viewModel.queuePromotionalOffer($0, for: subscription) }
            )
        case let .promotionalPrices(subscription, offer):
            PromotionalOfferPricesSheet(
                subscription: subscription, offer: offer,
                problems: { viewModel.problems(forPrices: $0, of: offer, subscription: subscription) },
                onCancel: close,
                onAdd: { viewModel.queuePromotionalPrices($0, for: offer, subscription: subscription) }
            )
        case let .newWinBack(subscription):
            WinBackOfferSheet(
                subscription: subscription,
                problems: { viewModel.problems(for: $0, subscription: subscription) },
                onCancel: close,
                onAdd: { viewModel.queueWinBackOffer($0, for: subscription) }
            )
        case let .winBackSettings(subscription, offer):
            WinBackSettingsSheet(
                offer: offer, startIsFixed: offer.hasStarted(today: viewModel.today()),
                problems: { viewModel.problems(forSettings: $0, of: offer) },
                onCancel: close,
                onAdd: { viewModel.queueWinBackSettings($0, for: offer, subscription: subscription) }
            )
        case let .newOfferCode(subscription):
            OfferCodeSheet(
                subscription: subscription,
                problems: { viewModel.problems(for: $0, subscription: subscription) },
                onCancel: close,
                onAdd: { viewModel.queueOfferCode($0, for: subscription) }
            )
        case let .customCode(subscription, code), let .oneTimeCodes(subscription, code):
            AddOfferCodesSheet(
                kind: route.isCustomCode ? .custom : .oneTime, code: code,
                customProblems: { viewModel.problems(for: $0, code: code, subscription: subscription) },
                batchProblems: { viewModel.problems(for: $0, code: code) },
                onCancel: close,
                onAddCustom: { viewModel.queueCustomCode($0, for: code, subscription: subscription) },
                onAddBatch: { viewModel.queueOneTimeCodes($0, for: code, subscription: subscription) }
            )
        }
    }
}
