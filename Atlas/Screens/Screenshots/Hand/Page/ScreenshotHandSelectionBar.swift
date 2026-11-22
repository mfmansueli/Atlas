//
//  ScreenshotHandSelectionBar.swift
//  Atlas
//

import SwiftUI

/// Over the set while a screenshot is selected: what it is and where it
/// comes from, ◀ ▶ to move it, Replace…, Delete…, Undo Change and ×.
struct ScreenshotHandSelectionBar: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let item: ScreenshotHandPageItem
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.handSelectionTitle(item))
                    .font(.headline)
                    .lineLimit(1)
                Text(viewModel.handOrigin(of: item.cell))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("screenshots.hand.origin")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task { await viewModel.moveSelectedHand(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(item.position == 0)
            .help("Move left")
            .accessibilityLabel(Text("Move left"))
            .accessibilityIdentifier("screenshots.hand.moveLeft")
            Button {
                Task { await viewModel.moveSelectedHand(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(item.position >= count - 1)
            .help("Move right")
            .accessibilityLabel(Text("Move right"))
            .accessibilityIdentifier("screenshots.hand.moveRight")
            if !item.isDeleted {
                Button("Replace…") { viewModel.handSheet = .replace(slotID: item.id, file: nil) }
                    .accessibilityIdentifier("screenshots.hand.replace")
                Button("Delete…", role: .destructive) { viewModel.handSheet = .delete(slotID: item.id) }
                    .disabled(!viewModel.canDeleteHand(item))
                    .help(viewModel.canDeleteHand(item) ? "" : String(localized: "Apple needs at least one screenshot in the primary language."))
                    .accessibilityIdentifier("screenshots.hand.delete")
            }
            if item.cell.hand?.isChanged == true {
                Button("Undo Change") { Task { await viewModel.undoSelectedHand() } }
                    .accessibilityIdentifier("screenshots.hand.undo")
            }
            Button {
                viewModel.handSelection = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Deselect")
            .accessibilityLabel(Text("Deselect"))
            .accessibilityIdentifier("screenshots.hand.deselect")
        }
        .controlSize(.small)
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.xSmall)
        .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Selected screenshot"))
        .accessibilityIdentifier("screenshots.hand.selectionBar")
    }
}
