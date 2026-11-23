//
//  AddOfferCodesSheet.swift
//  Atlas
//

import SwiftUI

/// Add Custom Code… or Add One-Time Codes… for an offer code App Store
/// Connect has: one custom code customers type, or a batch of codes Apple
/// makes. Add to Review & Push queues it.
struct AddOfferCodesSheet: View {
    enum Kind: Hashable {
        case custom
        case oneTime
    }

    let kind: Kind
    let code: ExistingOfferCode
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

    private var id: String { kind == .custom ? "pricing.customCode" : "pricing.oneTimeCodes" }

    private var problems: [SubscriptionOfferProblem] {
        switch kind {
        case .custom: customCode.map(customProblems) ?? []
        case .oneTime: oneTimeCodes.map(batchProblems) ?? []
        }
    }

    var body: some View {
        OfferSheetChrome(
            title: kind == .custom ? String(localized: "Custom code for “\(code.name)”") : String(localized: "One-time codes for “\(code.name)”"),
            detail: String(localized: "\(code.terms.summary). It waits in Review & Push; nothing changes in App Store Connect until you push."),
            footnote: code.codesSummary,
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
