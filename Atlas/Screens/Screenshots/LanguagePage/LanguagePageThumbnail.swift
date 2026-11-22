//
//  LanguagePageThumbnail.swift
//  Atlas
//

import SwiftUI

/// One screenshot on the language page, large: its render, file or live
/// image (or, with Suggested, drawn with the suggested caption and a purple
/// ring), its number, and its state under it ("Caption suggested",
/// "Replaced · not pushed", "Will be deleted", "Live"). Clicking selects it
/// for the bar above the set; a double click or Show Larger opens the
/// full-size viewer; dropping a file on it asks to replace it.
struct LanguagePageThumbnail: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let item: ScreenshotHandPageItem
    let localeName: String
    let width: CGFloat

    @State private var isTargeted = false

    private var cell: ScreenshotCell { item.cell }

    var body: some View {
        let status = viewModel.pageStatus(of: cell)
        let preview = suggestedPreview
        VStack(spacing: Spacing.xSmall) {
            Button {
                viewModel.selectHand(item)
            } label: {
                image(preview)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded { openViewer() })
            .contextMenu { menu }
            .dropDestination(for: URL.self) { urls, _ in
                guard !item.isDeleted, let file = ScreenshotHandDrop.files(from: urls).first else { return false }
                viewModel.handSelection = ScreenshotHandSelection(locale: cell.key.locale, displayType: cell.key.displayType, slotID: item.id)
                viewModel.handSheet = .replace(slotID: item.id, file: file)
                return true
            } isTargeted: { isTargeted = $0 }
            Pill(text: status.title, style: pillStyle(status.isSuggested))
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(status.isSuggested)))
        .accessibilityAddTraits(item.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { viewModel.selectHand(item) }
        .accessibilityAction(named: Text("Show Larger")) { openViewer() }
        .accessibilityIdentifier("screenshots.page.shot.\(item.position)")
    }

    @ViewBuilder
    private var menu: some View {
        Button("Show Larger") { openViewer() }
            .disabled(cell.image == CellImageSource.none)
        if !item.isDeleted {
            Divider()
            Button("Replace…") {
                select()
                viewModel.handSheet = .replace(slotID: item.id, file: nil)
            }
            Button("Delete…", role: .destructive) {
                select()
                viewModel.handSheet = .delete(slotID: item.id)
            }
            .disabled(!viewModel.canDeleteHand(item))
        }
        if cell.hand?.isChanged == true {
            Button("Undo Change") {
                select()
                Task { await viewModel.undoSelectedHand() }
            }
        }
    }

    private func select() {
        viewModel.handSelection = ScreenshotHandSelection(locale: cell.key.locale, displayType: cell.key.displayType, slotID: item.id)
    }

    /// The viewer shows the template's slots; a file or a deleted place has
    /// no slot there, so it opens at the nearest one.
    private func openViewer() {
        guard cell.image != CellImageSource.none else { return }
        let slot = min(cell.key.slot, max(0, viewModel.matrix.slotCount(on: cell.key.displayType) - 1))
        viewModel.openViewer(ScreenshotCellKey(locale: cell.key.locale, displayType: cell.key.displayType, slot: slot))
    }

    private func pillStyle(_ isSuggested: Bool) -> PillStyle {
        if isSuggested { return .machineTranslated }
        if item.isDeleted { return .danger }
        return cell.state.isPending ? .accent : .outline
    }

    /// With Suggested picked and a caption suggested: the slot drawn with it.
    private var suggestedPreview: SlotPreview? {
        guard viewModel.showsSuggestedCaptions, cell.image.renderJob != nil, cell.hand?.isChanged != true,
              let caption = viewModel.proposedCaption(locale: cell.key.locale, slot: cell.key.slot) else { return nil }
        return viewModel.proposedPreview(for: caption, on: cell.key.displayType)
    }

    private var height: CGFloat {
        let size = viewModel.pixelSize(for: cell.key.displayType)
        return (width * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
    }

    @ViewBuilder
    private func image(_ preview: SlotPreview?) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(6, width * 0.06), style: .continuous)
        Group {
            if let preview {
                SlotPreviewImage(preview: preview, capture: viewModel.captureImage(for: preview), width: width)
            } else if let image = viewModel.thumbnail(for: cell) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: width, height: height)
            } else {
                ZStack {
                    Palette.fill2
                    if viewModel.isRendering(cell) || cell.image.handFile != nil { ProgressView().controlSize(.small) }
                }
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .opacity(item.isDeleted ? 0.45 : 1)
        .overlay(alignment: .topLeading) {
            Text(item.position + 1, format: .number)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(Spacing.xxSmall)
                .accessibilityHidden(true)
        }
        .overlay {
            if item.isDeleted {
                Text("Will be deleted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xSmall)
                    .padding(.vertical, 2)
                    .background(Palette.dangerMark, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            shape.strokeBorder(ringColor(preview), lineWidth: ringWidth(preview))
        }
        .contentShape(shape)
    }

    private func ringColor(_ preview: SlotPreview?) -> Color {
        if item.isSelected || isTargeted { return Palette.accent }
        return preview == nil ? Palette.separator2 : Palette.suggestionBadge
    }

    private func ringWidth(_ preview: SlotPreview?) -> CGFloat {
        if item.isSelected || isTargeted { return 3 }
        return preview == nil ? 0.5 : 2.5
    }

    /// "Screenshot 2, German, Replaced · not pushed, selected".
    private func accessibilityText(_ isSuggested: Bool) -> String {
        var parts = [String(localized: "Screenshot \(item.position + 1)"), localeName]
        parts.append(isSuggested ? String(localized: "caption suggested") : cell.state.title)
        if item.isSelected { parts.append(String(localized: "selected")) }
        return parts.joined(separator: ", ")
    }
}
