//
//  CaptureCoverageRowView.swift
//  Atlas
//

import AppKit
import SwiftUI

/// One locale's captures: its name, where they came from, and each slot's
/// capture labelled Localized, English UI or Wrong size; a click on one
/// shows it large, ⌘-click selects it to redo, and a PNG dropped on one
/// replaces it.
struct CaptureCoverageRowView: View {
    let row: CaptureCoverage.Row
    let thumbnailWidth: CGFloat
    let images: CaptureImageStore
    var isSelected: (CaptureCoverage.Cell) -> Bool = { _ in false }
    let onView: (CaptureCoverage.Cell) -> Void
    var onToggle: (CaptureCoverage.Cell) -> Void = { _ in }
    var onToggleRow: () -> Void = {}
    var onReplace: (CaptureCoverage.Cell, URL) -> Void = { _, _ in }
    @State private var dropTarget: Int?

    /// Captures load at twice the thumbnail's width.
    private var imageWidth: Int { Int(thumbnailWidth * 2) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggleRow) {
                HStack(spacing: Spacing.xSmall) {
                    FlagTile(regionCode: row.locale.regionCode)
                        .frame(width: 20)
                    Text(row.locale.name)
                        .font(.callout)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("Select \(row.locale.name)’s captures"))
            .accessibilityIdentifier("captures.coverage.\(row.locale.code).select")
            .frame(width: CaptureCoverageView.localeWidth, alignment: .leading)
            Text(row.sourceText)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .frame(width: CaptureCoverageView.sourceWidth, alignment: .leading)
            ForEach(row.cells) { cell in
                Button {
                    if NSEvent.modifierFlags.contains(.command) { onToggle(cell) } else if cell.capture != nil { onView(cell) } else { onToggle(cell) }
                } label: { cellView(cell) }
                    .buttonStyle(.plain)
                    .help(help(cell))
                    .accessibilityIdentifier("captures.coverage.\(row.locale.code).\(cell.slot + 1)")
                    // The button merges its badge: VoiceOver hears it here.
                    .accessibilityValue(cell.stale != nil ? Text("Out of date") : Text(cell.label.title))
                    .accessibilityAddTraits(isSelected(cell) ? .isSelected : [])
                    .accessibilityAction(named: Text(isSelected(cell) ? "Deselect" : "Select")) { onToggle(cell) }
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let url = urls.first else { return false }
                        onReplace(cell, url)
                        return true
                    } isTargeted: { dropTarget = $0 ? cell.slot : (dropTarget == cell.slot ? nil : dropTarget) }
                    .frame(width: thumbnailWidth + 24, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .onAppear {
            images.request(row.cells.compactMap(\.capture), width: imageWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("captures.coverage.\(row.locale.code)")
    }

    private func cellView(_ cell: CaptureCoverage.Cell) -> some View {
        VStack(spacing: Spacing.xxSmall) {
            ZStack(alignment: .topLeading) {
                thumbnail(cell)
                if case .primaryInterface = cell.label {
                    InterfaceChip()
                        .offset(x: 3, y: 3)
                }
            }
            .overlay {
                if isSelected(cell) || dropTarget == cell.slot {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Palette.accent, lineWidth: 2)
                        .padding(-2)
                }
            }
            if cell.stale != nil {
                Text("Out of date")
                    .font(.caption)
                    .foregroundStyle(Palette.warning)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("captures.coverage.\(row.locale.code).\(cell.slot + 1).stale")
            } else {
                Text(cell.label.title)
                    .font(.caption)
                    .foregroundStyle(labelColor(cell.label))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: thumbnailWidth + 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(row.locale.name) capture \(cell.slot + 1), \(cell.stale == nil ? cell.label.title : String(localized: "Out of date"))"))
    }

    private func help(_ cell: CaptureCoverage.Cell) -> Text {
        if let stale = cell.stale { return Text("Out of date: \(stale.reason)") }
        return cell.capture == nil ? Text(cell.label.title) : Text("View it larger; ⌘-click to select it")
    }

    @ViewBuilder
    private func thumbnail(_ cell: CaptureCoverage.Cell) -> some View {
        let height = thumbnailWidth * aspect(of: cell.capture)
        if let image = images.image(for: cell.capture, width: imageWidth) {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailWidth, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(cell.label == .wrongSize ? Palette.dangerMark : Palette.separator, lineWidth: cell.label == .wrongSize ? 1.5 : 0.5)
                }
        } else {
            ImageLoadingTile(
                isLoading: images.isLoading(cell.capture, width: imageWidth), systemImage: nil, fill: Palette.fill1,
                controlSize: thumbnailWidth >= 60 ? .small : .mini
            )
            .frame(width: thumbnailWidth, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Palette.separator, style: StrokeStyle(lineWidth: 0.5, dash: cell.capture == nil ? [3, 2] : []))
            }
        }
    }

    private func aspect(of capture: ScreenshotCapture?) -> CGFloat {
        guard let size = capture?.pixelSize, size.width > 0 else { return thumbnailWidth > 50 ? 0.75 : 2.17 }
        return CGFloat(size.height) / CGFloat(size.width)
    }

    private func labelColor(_ label: CaptureCoverage.Label) -> Color {
        switch label {
        case .localized: Palette.label2
        case .primaryInterface, .missing: Palette.label3
        case .wrongSize: Palette.danger
        }
    }
}
