//
//  AddOfferCodesSheet.swift
//  Atlas
//

import SwiftUI

/// Add Custom Code… or Add One-Time Codes… for an offer code App Store
/// Connect has (a subscription's or an in-app purchase's): one custom code
/// customers type, or a batch of codes Apple makes. Add to Review & Push
/// queues it.
struct AddOfferCodesSheet: View {
    enum Kind: Hashable {
        case custom
        case oneTime
    }

    /// What the sheet says of the offer code it adds to.
    struct Offer: Hashable {
        var name: String
        /// "Free for 3 months", "$1.99 instead of $4.99".
        var termsSummary: String
        /// "LUMENPOD · 500 one-time codes".
        var codesSummary: String
    }

    let kind: Kind
    let offer: Offer
    let customProblems: (NewCustomCode) -> [SubscriptionOfferProblem]
    let batchProblems: (NewOneTimeCodes) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAddCustom: (NewCustomCode) -> Void
    let onAddBatch: (NewOneTimeCodes) -> Void

    @State private var customCode: NewCustomCode? = NewCustomCode(code: "", numberOfCodes: 1000)
    @State private var oneTimeCodes: NewOneTimeCodes? = NewOneTimeCodes(
        numberOfCodes: 500, expirationDate: Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    )
    @State private var showsProblems = false

    init(
        kind: Kind, offer: Offer,
        customProblems: @escaping (NewCustomCode) -> [SubscriptionOfferProblem],
        batchProblems: @escaping (NewOneTimeCodes) -> [SubscriptionOfferProblem],
        onCancel: @escaping () -> Void,
        onAddCustom: @escaping (NewCustomCode) -> Void,
        onAddBatch: @escaping (NewOneTimeCodes) -> Void
    ) {
        self.kind = kind
        self.offer = offer
        self.customProblems = customProblems
        self.batchProblems = batchProblems
        self.onCancel = onCancel
        self.onAddCustom = onAddCustom
        self.onAddBatch = onAddBatch
    }

    /// For a subscription's offer code.
    init(
        kind: Kind, code: ExistingOfferCode,
        customProblems: @escaping (NewCustomCode) -> [SubscriptionOfferProblem],
        batchProblems: @escaping (NewOneTimeCodes) -> [SubscriptionOfferProblem],
        onCancel: @escaping () -> Void,
        onAddCustom: @escaping (NewCustomCode) -> Void,
        onAddBatch: @escaping (NewOneTimeCodes) -> Void
    ) {
        self.init(
            kind: kind, offer: Offer(name: code.name, termsSummary: code.terms.summary, codesSummary: code.codesSummary),
            customProblems: customProblems, batchProblems: batchProblems,
            onCancel: onCancel, onAddCustom: onAddCustom, onAddBatch: onAddBatch
        )
    }

    private var id: String { kind == .custom ? "pricing.customCode" : "pricing.oneTimeCodes" }

    private var problems: [SubscriptionOfferProblem] {
        switch kind {
        case .custom: customCode.map(customProblems) ?? []
        case .oneTime: oneTimeCodes.map(batchProblems) ?? []
        }
    }

    var body: some View {
        OfferSheetChrome(
            title: kind == .custom ? String(localized: "Custom Code for “\(offer.name)”") : String(localized: "One-Time Codes for “\(offer.name)”"),
            detail: String(localized: "\(offer.termsSummary). Nothing changes until you push."),
            footnote: offer.codesSummary,
            identifier: id,
            problems: problems,
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: add,
            content: {
                OfferCodesFields(
                    customCode: $customCode, oneTimeCodes: $oneTimeCodes, identifier: id,
                    showsCustomCode: kind == .custom, showsOneTimeCodes: kind == .oneTime, canTurnOff: false
                )
            }
        )
    }

    private func add() {
        switch kind {
        case .custom: if let customCode { onAddCustom(customCode) }
        case .oneTime: if let oneTimeCodes { onAddBatch(oneTimeCodes) }
        }
    }
}
