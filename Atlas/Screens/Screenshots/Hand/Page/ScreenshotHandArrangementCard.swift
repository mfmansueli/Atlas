//
//  ScreenshotHandArrangementCard.swift
//  Atlas
//

import SwiftUI

/// Screenshots an assistant suggested deleting, or the set's new order:
/// which ones, small and numbered as they are now, who and why, with
/// Dismiss and Accept. It arrives and settles like any suggestion.
struct ScreenshotHandArrangementCard: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let arrangement: ScreenshotHandArrangement

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(viewModel.handArrangementTitle(arrangement))
                .font(.body.weight(.semibold))
                .accessibilityIdentifier("screenshots.hand.arrangement.title")
            HStack(spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                    .fixedSize()
                AssistantChip(name: arrangement.client)
            }
            thumbnails
            Text(arrangement.reason)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if !arrangement.evidence.isEmpty {
                Text(arrangement.evidence.map(\.ref).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            HStack(spacing: Spacing.xSmall) {
                Spacer()
                Button("Dismiss") { Task { await viewModel.dismissHandArrangement(arrangement) } }
                    .accessibilityIdentifier("screenshots.hand.arrangement.dismiss")
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("screenshots.hand.arrangement.accept")
            }
            .controlSize(.regular)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .suggestionSurface(isSettling: isSettling, arrivalKey: arrangement.id, arrivedAt: arrangement.receivedAt, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.arrangement")
    }

    /// The screenshots it names, numbered as they are now (in the new
    /// order for an order).
    private var thumbnails: some View {
        let cells = viewModel.handArrangementCells(arrangement)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Spacing.xSmall) {
                ForEach(Array(zip(arrangement.places.indices, cells)), id: \.0) { index, cell in
                    let number = String(arrangement.places[index].position + 1)
                    if let cell {
                        ScreenshotHandCurrentImage(viewModel: viewModel, cell: cell, width: 44, label: number)
                    } else {
                        VStack(spacing: Spacing.xSmall) {
                            Palette.fill2
                                .frame(width: 44, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                            Pill(text: number, style: .outline)
                                .fixedSize()
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.handArrangementTitle(arrangement)))
    }

    private func accept() {
        AcceptSettle.perform(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            Task.immediate { await viewModel.acceptHandArrangement(arrangement) }
        }
    }
}
