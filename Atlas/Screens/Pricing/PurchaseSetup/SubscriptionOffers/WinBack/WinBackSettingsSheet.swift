//
//  WinBackSettingsSheet.swift
//  Atlas
//

import SwiftUI

/// Edit… for a win-back offer App Store Connect has: who's eligible, when
/// it runs, its priority and promotion (its terms and prices can't change).
/// The push changes only what's different.
struct WinBackSettingsSheet: View {
    let offer: ExistingWinBackOffer
    let startIsFixed: Bool
    let problems: (WinBackOfferSettings) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (WinBackOfferSettings) -> Void

    @State private var settings: WinBackOfferSettings
    @State private var showsProblems = false

    private static let id = "pricing.winBackSettings"

    init(
        offer: ExistingWinBackOffer, startIsFixed: Bool, problems: @escaping (WinBackOfferSettings) -> [SubscriptionOfferProblem],
        onCancel: @escaping () -> Void, onAdd: @escaping (WinBackOfferSettings) -> Void
    ) {
        self.offer = offer
        self.startIsFixed = startIsFixed
        self.problems = problems
        self.onCancel = onCancel
        self.onAdd = onAdd
        _settings = State(initialValue: offer.settings)
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Edit “\(offer.referenceName)”"),
            detail: String(localized: "\(offer.terms.summary). To change terms or prices, delete it and add another."),
            footnote: String(localized: "Offer ID: \(offer.offerID)"),
            identifier: Self.id,
            problems: problems(settings),
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: { onAdd(settings) },
            content: {
                WinBackSettingsFields(settings: $settings, identifier: Self.id, startIsFixed: startIsFixed)
            }
        )
    }
}
