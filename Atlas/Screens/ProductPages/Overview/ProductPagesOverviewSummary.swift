//
//  ProductPagesOverviewSummary.swift
//  Atlas
//

import Foundation

/// Custom Product Pages on the Overview's After release: how many pages,
/// how many are visible and rejected, and the one people download most
/// from, against the default page.
struct ProductPagesOverviewSummary: Hashable, Sendable {
    /// "6 pages · 3 visible on the App Store · 1 rejected".
    var line: String
    /// "Best: “Prompts”, 32.4% of visitors download, about the same as the
    /// default page."; nil without numbers to compare.
    var best: String?
    /// Suggested pages waiting.
    var suggestionCount = 0

    @MainActor
    static func make(_ model: ProductPagesViewModel) -> ProductPagesOverviewSummary? {
        guard model.state.value != nil else { return nil }
        let pages = model.pages
        guard !pages.isEmpty else {
            return ProductPagesOverviewSummary(
                line: String(localized: "No pages yet"), suggestionCount: model.pageSuggestions.count
            )
        }
        var parts = [pages.count == 1 ? String(localized: "1 page") : String(localized: "\(pages.count) pages")]
        let visible = pages.count(where: { $0.state.isApproved && model.isVisible($0) })
        parts.append(String(localized: "\(visible) visible on the App Store"))
        let rejected = pages.count(where: { $0.state == .rejected })
        if rejected > 0 { parts.append(String(localized: "\(rejected) rejected")) }
        return ProductPagesOverviewSummary(
            line: parts.joined(separator: " · "), best: best(model, pages: pages), suggestionCount: model.pageSuggestions.count
        )
    }

    @MainActor
    private static func best(_ model: ProductPagesViewModel, pages: [ProductPage]) -> String? {
        let compared = pages.compactMap { page -> (page: ProductPage, rate: Double, comparison: ProductPageComparison)? in
            guard let rate = model.numbers(of: page)?.downloadRate, let comparison = model.comparison(of: page),
                  !comparison.isTooFew else { return nil }
            return (page, rate, comparison)
        }
        guard let top = compared.max(by: { $0.rate < $1.rate }) else { return nil }
        let rate = ProductPageNumbersText.rate(top.rate)
        let against = switch top.comparison {
        case .aboutTheSame, .tooFewViews: String(localized: "about the same as the default page")
        case let .above(points): String(localized: "\(points.formatted(.number.precision(.fractionLength(1)))) points above the default page")
        case let .below(points): String(localized: "\(points.formatted(.number.precision(.fractionLength(1)))) points below the default page")
        }
        return String(localized: "Best: “\(top.page.name)”, \(rate) of visitors download, \(against).")
    }
}
