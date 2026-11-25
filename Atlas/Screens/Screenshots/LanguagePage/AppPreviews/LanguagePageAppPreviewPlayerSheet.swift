//
//  LanguagePageAppPreviewPlayerSheet.swift
//  Atlas
//

import SwiftUI

/// An App Preview from the language page's row, playing with its sound and
/// controls: the live movie App Store Connect streams, or the file waiting
/// in Review & Push. One Apple hasn't processed yet says so instead.
struct LanguagePageAppPreviewPlayerSheet: View {
    let item: LanguagePageAppPreview
    let localeName: String

    @State private var player = AppPreviewPlayerModel()
    @Environment(\.dismiss) private var dismiss

    /// The video at most this tall, so the sheet fits the smallest window.
    private static let videoHeight: CGFloat = 300
    private static let maximumWidth: CGFloat = 520

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("App Preview \(item.position + 1)", comment: "kind:title")
                    .atlasTextStyle(.title2)
                Text(verbatim: subtitle)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if let url = item.movieURL {
                AppPreviewPlayer(model: player, file: item.playerFile, url: url, musicTitle: nil, poster: nil, width: width)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Apple is still processing this App Preview, so it can’t play yet.", comment: "kind:empty")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("screenshots.page.appPreview.processing")
            }
            HStack {
                Spacer()
                Button(String(localized: "Done", comment: "kind:button")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("screenshots.page.appPreview.done")
            }
        }
        .padding(Spacing.xLarge)
        .frame(minWidth: 360)
        .onDisappear { player.pause() }
        .onExitCommand { dismiss() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.page.appPreview.player")
    }

    /// "English (U.S.) · Mac · Live".
    private var subtitle: String {
        [localeName, item.displayType.title, item.stateTitle].joined(separator: " · ")
    }

    private var width: CGFloat {
        let size = item.pixelSize
        let aspect = CGFloat(size.height) / CGFloat(max(size.width, 1))
        return min(Self.maximumWidth, (Self.videoHeight / max(aspect, 0.1)).rounded())
    }
}
