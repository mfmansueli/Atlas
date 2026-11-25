//
//  ReviewShotSizeOfferBox.swift
//  Atlas
//

import SwiftUI

/// Under an accepted review screenshot Apple refused for its dimensions
/// (README — Pricing: review screenshots): the one 640 × 920 copy, said to
/// come from developers' reports, not Apple; or, once that copy was refused
/// too, what to do. Amber, as every refusal.
struct ReviewShotSizeOfferBox: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct
    let offer: ReviewShotSizeCopy.Offer

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Palette.warn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                switch offer {
                case let .copy(details):
                    Text(String(localized: "Apple refused its size", comment: "kind:title"))
                        .atlasTextStyle(.callout)
                        .fontWeight(.semibold)
                        .help(details)
                    Text(String(
                        localized: "Apple names no size. Developers report 640 × 920 px works, so Atlas can push a copy at that size with the whole image.",
                        comment: "kind:description"
                    ))
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                case .copyRefused:
                    Text(String(localized: "Apple refused the 640 × 920 copy too", comment: "kind:title"))
                        .atlasTextStyle(.callout)
                        .fontWeight(.semibold)
                    Text(String(localized: "Replace it with another image.", comment: "kind:description"))
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if case .copy = offer {
                Button(String(localized: "Use a 640 × 920 Copy", comment: "kind:button")) { useSizedCopy() }
                    .secondaryButton()
                    .accessibilityIdentifier("pricing.card.reviewShots.sizedCopy")
            }
        }
        .padding(Spacing.medium)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.reviewShots.sizeOffer")
    }

    private func useSizedCopy() {
        let id = viewModel.reviewShotChangeID(for: product)
        guard let before = viewModel.queue.change(id: id) else { return }
        let details = viewModel.setup.details.details(for: id)
        do {
            try viewModel.useSizedCopy(for: product)
            viewModel.sayReviewShots(String(
                localized: "A 640 × 920 copy replaces it in Review & Push. The size comes from developers’ reports, not Apple.",
                comment: "kind:toast"
            )) { [viewModel] in
                viewModel.restoreReviewShot(before, details: details)
            }
        } catch {
            viewModel.sayReviewShots(String(localized: "The copy couldn’t be made. Replace it with another image.", comment: "kind:error"), offersReview: false)
        }
    }
}
