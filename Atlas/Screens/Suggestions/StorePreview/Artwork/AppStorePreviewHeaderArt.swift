//
//  AppStorePreviewHeaderArt.swift
//  Atlas
//

import SwiftUI

/// The header at the top of the App Store preview: the centre of the 21:9,
/// as an iPhone shows it, marked Not pushed while a change waits. A click
/// opens Screenshots in that language.
struct AppStorePreviewHeaderArt: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    let slot: StoreArtworkSlot
    let content: StoreArtworkSlot.Content
    var onOpen: (() -> Void)?

    /// The preview's header, or nil when the page starts with the icon and
    /// name.
    static func shown(
        _ artwork: AppStorePreviewArtwork, services: any ScreenshotsServices, app: StoreApp, onOpen: (() -> Void)?
    ) -> Self? {
        artwork.headerContent.map { Self(services: services, app: app, slot: artwork.header, content: $0, onOpen: onOpen) }
    }

    var body: some View {
        let height = Metrics.storePreviewHeaderHeight
        let width = (height * CGFloat(slot.place.kind.pixelSize.width) / CGFloat(slot.place.kind.pixelSize.height)).rounded()
        let art = Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                StoreArtworkImage(services: services, app: app, content: content, width: width, height: height)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if slot.state.isNotPushed {
                    Pill(text: String(localized: "Not pushed", comment: "kind:status"), style: .accent)
                        .fixedSize()
                        .padding(Spacing.small)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Header artwork, \(StoreLocaleCatalog.locale(code: slot.locale)?.name ?? slot.locale)", comment: "kind:label"))
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("storePreview.header")
        if let onOpen {
            Button(action: onOpen) { art.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .help(Text("Edit in Screenshots", comment: "kind:help"))
        } else {
            art
        }
    }
}
