//
//  ProductPageRow.swift
//  Atlas
//

import AppKit
import SwiftUI

/// One page in the list: its name, languages and keywords, its status
/// (with a newer version's), whether it's visible, its numbers and download
/// rate against the default page's, and Copy Link. Clicking it opens the
/// editor.
struct ProductPageRow: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let isCompact: Bool

    static let nameMinimum: CGFloat = 180
    static let statusWidth: CGFloat = 150
    static let funnelWidth: CGFloat = 180
    static let rateWidth: CGFloat = 140
    static let copyWidth: CGFloat = 40
    static let subscribersWidth: CGFloat = 120
    static let trialToPaidWidth: CGFloat = 110

    var body: some View {
        HStack(alignment: isCompact ? .top : .center, spacing: Spacing.medium) {
            Button {
                viewModel.open(page.id)
            } label: {
                Group {
                    if isCompact { compactLabel } else { wideLabel }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(spokenLabel))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("pages.row.\(page.id)")
            copyButton
                .frame(width: Self.copyWidth, alignment: .trailing)
                .padding(.top, isCompact ? Spacing.small : 0)
        }
        .padding(.horizontal, Spacing.medium)
        .frame(minHeight: 52)
    }

    // MARK: - Layouts

    private var wideLabel: some View {
        HStack(spacing: Spacing.medium) {
            name.frame(minWidth: Self.nameMinimum, maxWidth: .infinity, alignment: .leading)
            status.frame(width: Self.statusWidth, alignment: .leading)
            ProductPageFunnelText(numbers: viewModel.numbers(of: page), emptyText: ProductPageNumbersText.noNumbers(for: page))
                .frame(width: Self.funnelWidth, alignment: .leading)
            rate.frame(width: Self.rateWidth, alignment: .leading)
            if viewModel.hasSubscriberNumbers {
                ProductPageSubscribersCells(
                    subscribers: viewModel.subscribers(of: page), average: viewModel.averageTrialToPaid,
                    widths: (Self.subscribersWidth, Self.trialToPaidWidth)
                )
            }
        }
        .padding(.vertical, Spacing.small)
    }

    private var compactLabel: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                name
                Spacer(minLength: Spacing.small)
                status
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
                ProductPageFunnelText(numbers: viewModel.numbers(of: page), emptyText: ProductPageNumbersText.noNumbers(for: page))
                rate
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, Spacing.small)
    }

    // MARK: - Cells

    private var name: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Spacing.xSmall) {
                if viewModel.pendingCount(of: page) > 0 || page.isDraft {
                    UnsavedDot(size: 6)
                        .help(Text("Not pushed"))
                }
                Text(page.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            Text(viewModel.subtitle(of: page))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(isCompact ? 2 : 1)
                .fixedSize(horizontal: false, vertical: isCompact)
        }
    }

    private var status: some View {
        VStack(alignment: isCompact ? .trailing : .leading, spacing: 2) {
            // One above the other: side by side, "Approved" and "New version
            // in review" ran into the numbers column.
            Pill(text: page.state.title, style: page.state.pillStyle)
                .fixedSize()
            if let next = viewModel.nextVersionText(of: page) {
                Pill(text: next, style: .warning)
                    .fixedSize()
            }
            if let visibility = viewModel.visibilityText(of: page) {
                Text(visibility)
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isVisible(page) && page.state.isApproved ? Palette.label2 : Palette.label3)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var rate: some View {
        if let numbers = viewModel.numbers(of: page), let rate = numbers.downloadRate {
            let comparison = viewModel.comparison(of: page)
            VStack(alignment: .leading, spacing: 1) {
                Text(ProductPageNumbersText.rate(rate))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(comparison?.isTooFew == true ? Palette.label3 : Palette.label)
                if let comparison {
                    Text(comparison.text)
                        .font(.subheadline)
                        .foregroundStyle(Self.color(comparison))
                        .lineLimit(1)
                        .accessibilityLabel(Text(comparison.spoken))
                }
            }
        } else {
            // Keeps the column: an empty view takes no room, and the row's
            // status and numbers slid one column right of their headers.
            Color.clear.frame(height: 1)
        }
    }

    static func color(_ comparison: ProductPageComparison) -> Color {
        switch comparison {
        case .above: Palette.decrease
        case .below: Palette.warn
        case .aboutTheSame: Palette.label2
        case .tooFewViews: Palette.label3
        }
    }

    @ViewBuilder
    private var copyButton: some View {
        if page.url != nil {
            Button {
                guard let url = viewModel.copyLink(of: page) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            } label: {
                Label("Copy link", systemImage: "link")
                    .labelStyle(.iconOnly)
            }
            .controlSize(.regular)
            .buttonBorderShape(.circle)
            .help(Text("Copy the page’s App Store link"))
            .accessibilityLabel(Text("Copy the link to “\(page.name)”"))
            .accessibilityIdentifier("pages.copy.\(page.id)")
        } else {
            // Keeps the column, so a draft's status and numbers line up
            // with the other rows'.
            Color.clear
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var spokenLabel: String {
        var parts = [page.name, viewModel.subtitle(of: page), page.state.title]
        if let next = viewModel.nextVersionText(of: page) { parts.append(next) }
        if let visibility = viewModel.visibilityText(of: page) { parts.append(visibility) }
        if let numbers = viewModel.numbers(of: page) {
            parts.append(ProductPageNumbersText.spokenFunnel(numbers))
            if let rate = numbers.downloadRate {
                parts.append(String(localized: "download rate \(ProductPageNumbersText.rate(rate))"))
            }
            if let comparison = viewModel.comparison(of: page) { parts.append(comparison.spoken) }
        } else {
            parts.append(ProductPageNumbersText.noNumbers(for: page))
        }
        return parts.joined(separator: ", ")
    }
}
