//
//  OfferCodeSheet.swift
//  Atlas
//

import SwiftUI

/// New Offer Code… for a subscription App Store Connect has: its name, who
/// can redeem it, the terms, and the codes it comes with (a custom code,
/// one-time codes). Add to Review & Push queues it; the push creates it
/// with every price, then its codes.
struct OfferCodeSheet: View {
    let subscription: PricingProduct
    let problems: (NewOfferCode) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (NewOfferCode) -> Void

    @State private var code = NewOfferCode(name: "", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth))
    @State private var draft = OfferTermsDraft()
    @State private var showsProblems = false

    private static let id = "pricing.offerCode"

    private var current: NewOfferCode {
        var code = code
        code.terms = draft.terms
        return code
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Offer code"),
            detail: String(localized: "Free time or a lower price on \(subscription.name), with a code. Nothing changes until you push."),
            footnote: String(localized: "Up to 10 active offer codes per subscription."),
            identifier: Self.id,
            problems: problems(current),
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: { onAdd(current) },
            content: {
                Section {
                    TextField("Name", text: $code.name, prompt: Text("Podcast listeners"))
                        .accessibilityIdentifier("\(Self.id).name")
                } footer: {
                    Text("Only you see the name.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                eligibilitySection
                OfferTermsFields(draft: $draft, period: subscription.period ?? .oneMonth, identifier: Self.id)
                OfferCodesFields(customCode: $code.customCode, oneTimeCodes: $code.oneTimeCodes, identifier: Self.id)
            }
        )
    }

    private var eligibilitySection: some View {
        Section {
            ForEach(OfferCodeCustomerEligibility.allCases, id: \.self) { eligibility in
                Toggle(eligibility.title, isOn: Binding {
                    code.eligibilities.contains(eligibility)
                } set: { isOn in
                    code.eligibilities.removeAll { $0 == eligibility }
                    if isOn { code.eligibilities = OfferCodeCustomerEligibility.sorted(code.eligibilities + [eligibility]) }
                })
                .accessibilityIdentifier("\(Self.id).eligibility.\(eligibility.rawValue)")
            }
            if code.eligibilities.contains(.new) {
                Picker("For new subscribers", selection: $code.offerEligibility) {
                    ForEach(OfferCodeOfferEligibility.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("\(Self.id).offerEligibility")
            }
            Toggle("Renews after the offer", isOn: Binding { code.autoRenews ?? true } set: { code.autoRenews = $0 ? nil : false })
                .accessibilityIdentifier("\(Self.id).autoRenew")
        } header: {
            Text("Who can redeem it")
        }
    }
}
