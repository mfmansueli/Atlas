//
//  AppStorePreviewEventCard.swift
//  Atlas
//

import SwiftUI

/// The live In-App Event under the App Store preview's screenshots, as the
/// App Store shows it to people who don't have the app yet: "Happening
/// now" (or "Upcoming" before it starts) in the storefront's words, then
/// the event card (its badge, name and short description on its artwork),
/// then its dates.
struct AppStorePreviewEventCard: View {
    let event: AppStoreLiveEvent
    /// "Happening now" or "Upcoming", in the storefront's language.
    let label: String
    /// The file Atlas uploaded the card from, once found; App Store
    /// Connect's poster until then (`AppStoreEventArt`).
    @State private var art: InAppEventArtSource?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(label)
                .atlasTextStyle(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
            card
            Text("\(event.datesText()) · from In-App Events", comment: "kind:label An In-App Event's dates under its card on the App Store preview")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("storePreview.event")
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return InAppEventArtwork(event: event.event, source: art ?? AppStoreEventArt.poster(of: event.card), cornerRadius: Radius.card, maxPixel: 800)
            .aspectRatio(16 / 9, contentMode: .fit)
            .task(id: event.card) { art = await AppStoreEventArt.source(for: event) }
            .overlay {
                // The App Store's shade, so the words read on any artwork.
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.62), location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) { words }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Palette.separator2, lineWidth: 0.5) }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            if let badge = event.badgeTitle {
                Text(badge)
                    .atlasTextStyle(.footnote)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .opacity(0.85)
                    .lineLimit(1)
            }
            Text(event.name)
                .atlasTextStyle(.title3)
                .lineLimit(2)
            if !event.shortDescription.isEmpty {
                Text(event.shortDescription)
                    .atlasTextStyle(.subheadline)
                    .opacity(0.9)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, Spacing.medium)
        .padding(.bottom, Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Name, state and dates.
    private var accessibilityText: String {
        if event.isHappening {
            return String(
                localized: "In-App Event happening now: \(event.name), \(event.datesText())",
                comment: "kind:label VoiceOver for the live In-App Event on the App Store preview"
            )
        }
        return String(
            localized: "Upcoming In-App Event: \(event.name), \(event.datesText())",
            comment: "kind:label VoiceOver for an In-App Event on the App Store preview whose card shows before it starts"
        )
    }
}
