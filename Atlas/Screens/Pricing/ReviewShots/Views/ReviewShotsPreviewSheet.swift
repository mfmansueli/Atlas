//
//  ReviewShotsPreviewSheet.swift
//  Atlas
//

import SwiftUI

/// Show Larger (README — Pricing: review screenshots · Preview): the
/// assistant's review screenshots side by side, one per product, each with
/// the plan it shows, its checks and Dismiss / Accept; Accept All n at the
/// bottom. Only App Review sees them; nothing uploads before the push.
struct ReviewShotsPreviewSheet: View {
    @Bindable var viewModel: PricingViewModel

    /// Three phones side by side, as wide as the sheet allows.
    static let columnWidth: CGFloat = 190

    @Environment(\.dismiss) private var dismiss
    /// Dismissed here, still shown as such until the sheet closes.
    @State private var dismissed: [String: String] = [:]
    /// The products it opened with, so accepted and dismissed ones stay.
    @State private var shown: [PricingProduct] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text("Review Screenshots from \(client)")
                    .font(.title3.weight(.semibold))
                Text("Only App Review sees these, next to each product. Nothing uploads until you push.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.large) {
                    ForEach(shown) { product in
                        column(product)
                    }
                }
                .padding(.bottom, Spacing.small)
            }
            HStack(spacing: Spacing.small) {
                Text(footer)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pricing.reviewShots.preview.close")
                let suggested = viewModel.productsWithSuggestedReviewShot
                if suggested.count >= 2 {
                    Button {
                        let accepted = viewModel.acceptAllReviewShots()
                        viewModel.sayReviewShots(
                            String(localized: "Accepted \(accepted.count) review screenshots. They’re in Review & Push; nothing has uploaded.")
                        ) { [viewModel] in
                            viewModel.undoReviewShots(accepted)
                        }
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Text("Accept All")
                            SuggestionBadge(count: suggested.count)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("pricing.reviewShots.preview.acceptAll")
                }
            }
        }
        .padding(Spacing.xLarge)
        .frame(minWidth: 3 * Self.columnWidth + 2 * Spacing.large + 2 * Spacing.xLarge, minHeight: 520)
        .accessibilityIdentifier("pricing.reviewShots.preview")
        .onAppear(perform: pickProducts)
    }

    private func pickProducts() {
        let opened = viewModel.setup.reviewShotsPreviewProductID
        let products = viewModel.reviewShotProducts.filter { product in
            switch viewModel.reviewShotState(for: product) {
            case .suggested, .accepted: true
            default: false
            }
        }
        // The one it opened from first.
        shown = products.sorted { lhs, _ in lhs.id == opened }
    }

    private var client: String {
        shown.lazy.compactMap { viewModel.setup.details.details(for: viewModel.reviewShotChangeID(for: $0))?.client }.first
            ?? MCPClientKind.claudeCode.title
    }

    /// “iPhone 17 Pro · English (U.S.) · one image per product”.
    private var footer: String {
        let details = shown.lazy.compactMap { viewModel.setup.details.details(for: viewModel.reviewShotChangeID(for: $0)) }.first
        let parts = [details?.device, details?.language].compactMap(\.self) + [String(localized: "one image per product")]
        return parts.joined(separator: " · ")
    }

    private func column(_ product: PricingProduct) -> some View {
        let state = viewModel.reviewShotState(for: product)
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Group {
                switch state {
                case let .suggested(item), let .accepted(item):
                    ReviewShotThumbnail(url: item.fileURL, width: Self.columnWidth, label: item.details?.heading ?? product.name)
                default:
                    ImageLoadingTile(isLoading: false)
                        .frame(width: Self.columnWidth, height: Self.columnWidth * 2.17)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
            }
            Text(product.name)
                .font(.body.weight(.semibold))
            if let details = item(of: state)?.details {
                Text(planLine(details))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                if !details.checks.isEmpty {
                    Text(details.checks.map { "✓ " + $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            switch state {
            case .suggested:
                HStack(spacing: Spacing.small) {
                    Button("Dismiss") { dismissShot(of: product) }
                        .accessibilityIdentifier("pricing.reviewShots.preview.dismiss")
                    Button("Accept") {
                        viewModel.acceptReviewShot(for: product)
                        let text = String(localized: "\(product.name): review screenshot accepted. It’s in Review & Push.")
                        viewModel.sayReviewShots(text) { [viewModel] in
                            viewModel.undoReviewShot(for: product)
                        }
                    }
                    .rowActionButton()
                    .accessibilityIdentifier("pricing.reviewShots.preview.accept")
                }
            case .accepted:
                Label("Accepted · not pushed", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            default:
                if dismissed[product.id] != nil {
                    Text("Dismissed")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
        }
        .frame(width: Self.columnWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(product.name))
    }

    private func item(of state: ReviewShotsCardState) -> ReviewShotItem? {
        switch state {
        case let .suggested(item), let .accepted(item): item
        default: nil
        }
    }

    /// “Monthly selected · $4.99”.
    private func planLine(_ details: ReviewShotDetails) -> String {
        let plan = details.plan.map { String(localized: "\($0) selected") }
        return [plan, details.price].compactMap(\.self).joined(separator: " · ")
    }

    private func dismissShot(of product: PricingProduct) {
        let id = viewModel.reviewShotChangeID(for: product)
        guard let change = viewModel.queue.change(id: id) else { return }
        let details = viewModel.setup.details.details(for: id)
        viewModel.dismissReviewShot(for: product)
        dismissed[product.id] = id
        let text = String(localized: "Dismissed. \(product.name) still needs a review screenshot.")
        viewModel.sayReviewShots(text, offersReview: false) { [viewModel] in
            viewModel.restoreReviewShot(change, details: details)
        }
    }
}
