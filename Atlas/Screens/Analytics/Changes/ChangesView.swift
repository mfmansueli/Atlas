//
//  ChangesView.swift
//  Atlas
//

import SwiftUI

/// After Changes: what was pushed from Atlas, and each change's
/// 28 days before against 28 days after.
struct ChangesView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let onOpenPricing: () -> Void

    var body: some View {
        if viewModel.changes.isEmpty {
            ContentUnavailableView {
                Label("Nothing pushed yet", systemImage: "arrow.up.circle")
            } description: {
                Text("""
                When you push new screenshots, store page text, prices or paywall text from Atlas, its result shows \
                here: 28 days before against 28 days after.
                """)
            }
            .accessibilityIdentifier("analytics.changes.none")
        } else {
            HStack(alignment: .top, spacing: Spacing.medium) {
                list
                ScrollView {
                    if let change = viewModel.selectedChange {
                        ChangeResultView(change: change, result: viewModel.results[change.id], onOpenPricing: onOpenPricing)
                            .padding(.bottom, Spacing.xLarge)
                    }
                }
            }
            .accessibilityIdentifier("analytics.changes")
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pushed from Atlas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                ForEach(viewModel.changes) { change in
                    let isSelected = viewModel.selectedChange?.id == change.id
                    Button {
                        viewModel.selectedChangeID = change.id
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                                Text(AnalyticsText.day(change.date)).font(.caption).monospacedDigit().foregroundStyle(Palette.label2)
                                Text(change.title).font(.callout).lineLimit(1)
                            }
                            HStack(spacing: Spacing.small) {
                                Text(change.kind.area.title).font(.caption).foregroundStyle(Palette.label2)
                                Spacer(minLength: 0)
                                Text(status(change)).font(.caption).foregroundStyle(Palette.label2).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.xSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? Palette.accentTint : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("analytics.changes.row")
                }
            }
        }
        .frame(width: 240)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.bottom, Spacing.medium)
    }

    private func status(_ change: MeasuredChange) -> String {
        if change.kind == .prices { return String(localized: "In Pricing → Results") }
        return viewModel.results[change.id]?.statusText ?? String(localized: "No data")
    }
}
