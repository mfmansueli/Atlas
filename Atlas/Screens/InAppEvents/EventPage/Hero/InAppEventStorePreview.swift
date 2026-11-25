//
//  InAppEventStorePreview.swift
//  Atlas
//

import SwiftUI

/// "On the App Store" on the event's page (board 40): the event card as
/// people see it in search, Today and on the app's page (the art with the
/// App Store's text over it, then the app's row) or the details image at
/// the top of the event's page, in the language being written. The art is
/// the concept previewed, else the event's own; a click opens it full
/// size. The note says whose text and which concept it shows.
struct InAppEventStorePreview: View {
    let app: StoreApp
    let event: InAppEvent
    @Binding var kind: InAppEventMedia.Kind
    let card: InAppEventArtSource
    let details: InAppEventArtSource
    let texts: InAppEventShownTexts
    let note: InAppEventPreviewNote
    var isStacked = false
    var now = Date.now
    let onOpen: (InAppEventMedia.Kind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text("On the App Store")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.small)
                Picker("Where it’s shown", selection: $kind) {
                    Text("Event Card").tag(InAppEventMedia.Kind.card)
                    Text("Event Details").tag(InAppEventMedia.Kind.details)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .accessibilityIdentifier("events.preview.mode")
            }
            stage
            Text(note.text)
                .font(.system(size: 10, weight: note.isPreviewing ? .semibold : .regular))
                .foregroundStyle(note.isPreviewing ? Palette.ai : Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("events.preview.note")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.preview")
    }

    private var stage: some View {
        Group {
            if kind == .card {
                cardLockup
            } else if details.exists {
                detailsImage
            } else {
                missingDetails
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: isStacked ? nil : 268)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Event card

    private var cardLockup: some View {
        VStack(spacing: 0) {
            InAppEventPreviewArtButton(
                label: String(localized: "View the event card full size"), cornerRadius: 11, identifier: "events.preview.card",
                value: [texts.name, texts.shortDescription].filter { !$0.isEmpty }.joined(separator: ". ")
            ) {
                onOpen(.card)
            } content: {
                InAppEventArtwork(event: event, source: card, cornerRadius: 11, maxPixel: 1400)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { fade(from: 0.45) }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            badge(size: 10)
                            Text(texts.name)
                                .font(.system(size: 18, weight: .bold))
                                .lineLimit(2)
                                .accessibilityIdentifier("events.preview.name")
                            Text(texts.shortDescription)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                                .accessibilityIdentifier("events.preview.short")
                        }
                        .storeText(isRightToLeft: texts.isRightToLeft)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.bottom, 11)
                    }
            }
            HStack(spacing: Spacing.small) {
                AppIconTile(name: app.name, icon: app.icon, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("In-App Purchases")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.label2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Get")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.accentText)
                    .padding(.horizontal, Spacing.medium)
                    .frame(height: 24)
                    .background(Palette.fill2, in: Capsule())
            }
            .padding(.horizontal, 3)
            .padding(.top, Spacing.small)
            .padding(.bottom, 1)
            .accessibilityElement(children: .combine)
        }
        .padding(7)
        .frame(maxWidth: 440)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    // MARK: - Event details

    private var detailsImage: some View {
        InAppEventPreviewArtButton(
            label: String(localized: "View the event details image full size"), cornerRadius: 14, identifier: "events.preview.details"
        ) {
            onOpen(.details)
        } content: {
            InAppEventArtwork(event: event, source: details, cornerRadius: 14, maxPixel: 1200)
                .frame(width: 330 * 9 / 16, height: 330)
                .overlay { fade(from: 0.4) }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        badge(size: 9)
                        Text(texts.name)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                        Text(whenText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(texts.longDescription)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(5)
                    }
                    .storeText(isRightToLeft: texts.isRightToLeft)
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                }
        }
    }

    private var missingDetails: some View {
        VStack(spacing: Spacing.xSmall) {
            Image(systemName: StatusSymbol.needsYou.symbol)
                .font(.system(size: 22))
                .foregroundStyle(Palette.warn)
            Text("No event details image yet")
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("1080 × 1920 · shown at the top of the event’s page")
                .font(.system(size: 10))
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.medium)
        .frame(width: 330 * 9 / 16, height: 330)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.warnMark, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("events.preview.detailsMissing")
    }

    // MARK: - Parts

    @ViewBuilder
    private func badge(size: CGFloat) -> some View {
        if let badge = event.badge {
            Text(badge.title.uppercased())
                .font(.system(size: size, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func fade(from start: CGFloat) -> some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .frame(height: proxy.size.height * (1 - start))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }

    /// "Starts Dec 1", "Now available", "Ended".
    private var whenText: String {
        InAppEventWhenText.text(for: event, now: now)
    }
}

private extension View {
    /// The App Store's text over the art: white, leading, in its own
    /// language's direction.
    func storeText(isRightToLeft: Bool) -> some View {
        foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
