//
//  ScreenshotHandAddTile.swift
//  Atlas
//

import SwiftUI

/// The last tile of the set: Add Screenshots, by click or by dropping files
/// on it, while there's room.
struct ScreenshotHandAddTile: View {
    let room: Int
    let height: CGFloat
    let onAdd: () -> Void
    let onDrop: ([ScreenshotHandChosenFile]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                Text("Add Screenshots")
                    .font(.subheadline.weight(.semibold))
                Text("Drop PNG or JPEG files here, or click")
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                Text(room == 1 ? String(localized: "1 more allowed") : String(localized: "\(room) more allowed"))
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.xSmall)
            .frame(width: 112, height: height)
            .background(isTargeted ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isTargeted ? Palette.accent : Palette.label3, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            let files = ScreenshotHandDrop.files(from: urls)
            guard !files.isEmpty else { return false }
            onDrop(files)
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Add Screenshots, \(room) more allowed"))
        .accessibilityIdentifier("screenshots.hand.addTile")
    }
}
