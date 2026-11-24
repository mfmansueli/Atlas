//
//  ScreenshotAppPreviewTile.swift
//  Atlas
//

import SwiftUI

/// One App Preview in the language page's set: live, or a file waiting in
/// Review & Push (which live one it replaces), with Replace…, Move and
/// Delete in its menu.
struct ScreenshotAppPreviewTile: View {
    let slot: AppPreviewSetPush.Slot
    let position: Int
    let count: Int
    let displayType: ScreenshotDisplayType
    let onReplace: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            poster
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(title)
                        .atlasTextStyle(.footnote)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(state)
                        .atlasTextStyle(.footnote)
                        .foregroundStyle(slot.file == nil ? Palette.label2 : Palette.label)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                menu
            }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.appPreviews.tile.\(position + 1)")
    }

    static let width: CGFloat = 124

    private var aspect: CGFloat {
        guard let size = AppPreviewSpec.spec(for: displayType, landscape: false)?.pixelSize, size.width > 0 else { return 2 }
        return CGFloat(size.height) / CGFloat(size.width)
    }

    private var poster: some View {
        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            .fill(Palette.fill2)
            .frame(width: Self.width, height: (Self.width * aspect).rounded())
            .overlay {
                Image(systemName: "play.fill")
                    .atlasTextStyle(.title2)
                    .foregroundStyle(Palette.label2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("App Preview \(position + 1) of \(count), \(state)", comment: "kind:a11y"))
    }

    /// "1 · Lumen-de.mov".
    private var title: String {
        slot.fileName.isEmpty ? "\(position + 1)" : "\(position + 1) · \(slot.fileName)"
    }

    private var state: String {
        if slot.file == nil { return String(localized: "Live", comment: "kind:status") }
        if let client = slot.proposedBy { return String(localized: "Suggested by \(client) · not pushed", comment: "kind:status") }
        return slot.replacesID == nil
            ? String(localized: "Added · not pushed", comment: "kind:status")
            : String(localized: "Replaces the live one · not pushed", comment: "kind:status")
    }

    private var menu: some View {
        Menu {
            Button(String(localized: "Replace…", comment: "kind:menu"), action: onReplace)
            Button(String(localized: "Move Left", comment: "kind:menu")) { onMove(-1) }
                .disabled(position == 0)
            Button(String(localized: "Move Right", comment: "kind:menu")) { onMove(1) }
                .disabled(position >= count - 1)
            Divider()
            Button(String(localized: "Delete", comment: "kind:menu"), role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel(Text("App Preview \(position + 1) options", comment: "kind:a11y"))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityIdentifier("screenshots.appPreviews.menu.\(position + 1)")
    }
}
