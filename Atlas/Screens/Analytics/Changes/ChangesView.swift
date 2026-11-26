//
//  ChangesView.swift
//  Atlas
//

import SwiftUI

/// After Changes (board 92): what was pushed from Atlas, each with where
/// its result stands (better, waiting for data, too few to tell, in
/// Pricing → Results), and the selected one's 28 days before against the
/// days after.
struct ChangesView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onOpenPricing: () -> Void

    /// The list of pushes beside the result.
    private static let listWidth: CGFloat = 240

    var body: some View {
        if viewModel.changes.isEmpty {
            EmptyStateView(
                String(localized: "Nothing pushed yet", comment: "kind:empty-state · After Changes"),
                systemImage: AnalyticsTab.afterChanges.systemImage,
                text: String(
                    localized: "Push screenshots, texts, prices or paywall text to see each result here, 28 days before and after.",
                    comment: "kind:empty-state · After Changes"
                ),
                size: .inline
            )
            .accessibilityIdentifier("analytics.changes.none")
        } else {
            HStack(alignment: .top, spacing: Spacing.medium) {
                list
                ScrollView {
                    if let change = viewModel.selectedChange {
                        ChangeResultView(
                            change: change, result: viewModel.results[change.id], dataset: viewModel.dataset, context: viewModel.context,
                            onOpenPricing: onOpenPricing
                        )
                        .padding(.bottom, Spacing.xLarge)
                    }
                }
                .leavesChatRoom()
            }
            .accessibilityIdentifier("analytics.changes")
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pushed from Atlas", comment: "kind:section-title · After Changes")
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.label2)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .accessibilityAddTraits(.isHeader)
                ForEach(viewModel.changes) { change in
                    row(change)
                }
            }
        }
        .frame(width: Self.listWidth)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.bottom, Spacing.medium)
    }

    private func row(_ change: MeasuredChange) -> some View {
        let isSelected = viewModel.selectedChange?.id == change.id
        let status = ChangeStatus.make(change, result: viewModel.results[change.id])
        return Button {
            viewModel.selectedChangeID = change.id
        } label: {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text(AnalyticsText.day(change.date)).atlasTextStyle(.subheadline).monospacedDigit().foregroundStyle(Palette.label2)
                    Text(change.title).atlasTextStyle(.callout).fontWeight(.medium).lineLimit(1)
                }
                HStack(spacing: Spacing.small) {
                    Text(change.kind.area.title).atlasTextStyle(.subheadline).foregroundStyle(Palette.label3).lineLimit(1)
                    Spacer(minLength: 0)
                    Pill(text: status.title, style: status.pillStyle)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Palette.accentTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(AnalyticsText.day(change.date)), \(change.title), \(status.title)", comment: "kind:accessibility-label · After Changes row"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("analytics.changes.row")
    }
}
