//
//  EventArtworkConceptRow.swift
//  Atlas
//

import SwiftUI

/// One concept in the Artwork panel (board 47): its card and details
/// thumbnails, its name and tag (In use, Updated, Claude's pick),
/// why it was drawn this way, or "Drawing…" and "Waiting" while it isn't
/// in yet. A click shows it in the preview; the round button opens it
/// full size.
struct EventArtworkConceptRow: View {
    let row: EventArtworkPanelState.Row
    var locale: String?
    let onSelect: () -> Void
    let onView: () -> Void

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 9) {
                    HStack(spacing: 3) {
                        thumbnail(.card, width: 85)
                        thumbnail(.details, width: 27)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        // The tag beside the name when both fit, under it otherwise.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Spacing.xxSmall) {
                                name.fixedSize(horizontal: true, vertical: false)
                                tag
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                name
                                tag
                            }
                        }
                        Text(row.why)
                            .font(.footnote)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(row.tagTitle == nil ? 2 : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, Spacing.xSmall)
                .padding(.vertical, Spacing.xSmall)
                .padding(.trailing, 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(row.isDisabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(row.isPreviewed ? "\(row.name), shown in the preview" : row.name))
            .accessibilityValue(Text([row.tagTitle, row.why].compactMap(\.self).joined(separator: ", ")))
            .accessibilityAddTraits(row.isPreviewed ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("events.art.row.\(row.id)")
            if row.canView {
                Button(action: onView) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 26, height: 26)
                        .background(Palette.fill2, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
                .help("View full size  Space")
                .accessibilityLabel(Text("View \(row.name) full size"))
                .accessibilityIdentifier("events.art.row.view.\(row.id)")
            }
        }
        .opacity(row.isDisabled ? 0.75 : 1)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                .strokeBorder(ring, lineWidth: row.isPreviewed ? (contrast == .increased ? 2.5 : 2) : contrast == .increased ? 1 : 0.5)
        )
        .onHover { isHovered = $0 }
    }

    private var background: Color {
        if row.isPreviewed { return Palette.accentTint }
        return isHovered && !row.isDisabled ? Palette.fill1 : Palette.raised
    }

    private var ring: Color {
        if row.isPreviewed { return Palette.accent }
        return contrast == .increased ? Palette.label : Palette.separator2
    }

    private var name: some View {
        Text(row.name)
            .font(.callout.weight(.bold))
            .lineLimit(1)
    }

    @ViewBuilder private var tag: some View {
        if let tag = row.tagTitle, row.concept != nil {
            Pill(text: tag, style: row.tag == .inUse ? .increase : .machineTranslated)
                .fixedSize()
                .accessibilityIdentifier("events.art.row.tag.\(row.id)")
        }
    }

    @ViewBuilder
    private func thumbnail(_ kind: InAppEventMedia.Kind, width: CGFloat) -> some View {
        if row.state == .ready || row.state == .animating, let still = row.concept?.still(kind, locale: locale), still.kind == kind {
            InAppEventArtworkThumbnailFill(path: still.path, isVideo: still.isVideo)
                .frame(width: width, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .overlay {
                    if row.state == .animating { SkeletonBlock(width: width, height: 48, cornerRadius: Radius.menuRow).opacity(0.55) }
                }
        } else if row.isBusy {
            SkeletonBlock(width: width, height: 48, cornerRadius: Radius.menuRow)
                .overlay {
                    if row.state == .redrawing, let still = row.concept?.still(kind, locale: locale), still.kind == kind {
                        InAppEventArtworkThumbnailFill(path: still.path, isVideo: still.isVideo)
                            .opacity(0.4)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    }
                }
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
                .fill(Palette.fill2)
                .frame(width: width, height: 48)
        }
    }
}
