//
//  InAppPurchaseOfferCodeSheet.swift
//  Atlas
//

import SwiftUI

/// New Offer Code… for an in-app purchase App Store Connect has: its name,
/// who can redeem it (by how they've spent in the app), its price (free or
/// lower, equalized everywhere else) and where, and the codes it comes with
/// (a custom code, one-time codes). Add to Review & Push queues it; the
/// push creates it with every price, then its codes.
struct InAppPurchaseOfferCodeSheet: View {
    let purchase: PricingProduct
    let problems: (NewInAppPurchaseOfferCode) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (NewInAppPurchaseOfferCode) -> Void

    @State private var code = NewInAppPurchaseOfferCode(name: "", terms: InAppPurchaseOfferTerms(price: 0))
    @State private var draft = OfferTermsDraft()
    @State private var isFree = true
    @State private var showsProblems = false

    static let id = "pricing.iapOfferCode"

    private var current: NewInAppPurchaseOfferCode {
        var code = code
        code.terms = InAppPurchaseOfferPriceFields.terms(draft: draft, isFree: isFree)
        return code
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Offer code"),
            detail: String(localized: "\(purchase.name) free or at a lower price, with a code. Nothing changes until you push."),
            footnote: String(localized: "Up to \(NewInAppPurchaseOfferCode.activePerPurchase) active offer codes per in-app purchase."),
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
                InAppPurchaseOfferPriceFields(draft: $draft, isFree: $isFree, purchase: purchase, identifier: Self.id)
                OfferCodesFields(customCode: $code.customCode, oneTimeCodes: $code.oneTimeCodes, identifier: Self.id)
            }
        )
    }

    private var eligibilitySection: some View {
        Section {
            ForEach(InAppPurchaseOfferCodeEligibility.allCases, id: \.self) { eligibility in
                Toggle(eligibility.title, isOn: Binding {
                    code.eligibilities.contains(eligibility)
                } set: { isOn in
                    code.eligibilities.removeAll { $0 == eligibility }
                    if isOn { code.eligibilities = InAppPurchaseOfferCodeEligibility.sorted(code.eligibilities + [eligibility]) }
                })
                .accessibilityIdentifier("\(Self.id).eligibility.\(eligibility.rawValue)")
            }
        } header: {
            Text("Who can redeem it")
        } footer: {
            Text("By what they’ve bought in your app.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }
}
