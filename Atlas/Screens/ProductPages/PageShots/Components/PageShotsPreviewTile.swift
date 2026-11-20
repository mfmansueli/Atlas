//
//  PageShotsPreviewTile.swift
//  Atlas
//

import SwiftUI

/// A screenshot of the plan before it's made: laid out small from the
/// default set's capture with the page's caption, so Plan shows the order
/// and the words as they'll look.
struct PageShotsPreviewTile: View {
    let source: PageShotsSource
    let screens: [PageShotsScreen]
    let position: Int
    let locale: String
    let displayType: ScreenshotDisplayType
    let height: CGFloat

    @State private var image: CGImage?
    @State private var isLoading = true
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ImageLoadingTile(isLoading: isLoading)
            }
        }
        .frame(width: height * aspect, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isImage)
        .task(id: renderKey) { await render() }
    }

    private var caption: PageShotsCaption? {
        screens.indices.contains(position) ? screens[position].caption(locale) : nil
    }

    private var aspect: CGFloat { PageShotsTile.aspect(displayType) }

    private var renderKey: String {
        let slot = screens.indices.contains(position) ? screens[position].slot : -1
        return "\(position)|\(slot)|\(locale)|\(displayType.rawValue)|\(caption?.headline ?? "")|\(caption?.subhead ?? "")|\(Int(height))"
    }

    private var label: String {
        let name = screens.indices.contains(position) ? source.slotName(screens[position].slot) : ""
        return String(localized: "Screenshot \(position + 1), \(name): \(caption?.headline ?? "")")
    }

    private func render() async {
        isLoading = true
        guard let storeLocale = StoreLocaleCatalog.locale(code: locale) else {
            isLoading = false
            return
        }
        let width = Int(height * aspect * max(2, displayScale))
        if let made = await source.render(
            position: position, of: screens, caption: caption, locale: storeLocale, displayType: displayType, pixelWidth: width
        ) {
            image = ScreenshotPNG.image(made.data)
        }
        isLoading = false
    }
}
