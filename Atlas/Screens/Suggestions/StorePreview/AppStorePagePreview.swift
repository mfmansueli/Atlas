//
//  AppStorePagePreview.swift
//  Atlas
//

import SwiftUI

/// The app's App Store page in miniature, in the storefront's own language
/// and direction: icon, name and Get, ratings, age and category, the App
/// Preview and screenshots, the In-App Event whose card shows now, the texts, What's New
/// and the purchases. On the Overview each part opens the section editing
/// it when clicked, lit while the pointer is over it (README — redesign,
/// November 22: no tags on the preview), and the page stops after the
/// screenshots and the event (`isCompact`).
struct AppStorePagePreview<Shots: View>: View {
    let model: AppStorePreviewModel
    let appName: String
    var icon: AppIcon?
    var links: AppStorePreviewLinks?
    /// Name, ratings and screenshots only: the Overview's smaller preview.
    var isCompact = false
    @ViewBuilder var shots: () -> Shots
    /// The part under the pointer, by its link's title: it lights.
    @State private var hovered: String?

    private static var getBlue: Color { Color(red: 0.04, green: 0.52, blue: 1) }

    var body: some View {
        VStack(spacing: 0) {
            row(link: links?.storePage) { header }
            divider
            row(link: links?.appInformation, vertical: 8) { stats }
            divider
            shotsRow
            if let event = model.liveEvent {
                divider
                eventRow(event)
            }
            if !isCompact {
                divider
                row(link: nil) { texts }
                divider
                row(link: nil) { whatsNew }
                if !model.purchases.isEmpty {
                    divider
                    row(link: links?.pricing) { purchases }
                }
            }
        }
        .padding(6)
        .background(Palette.content, in: shape)
        .overlay(shape.strokeBorder(Palette.separator2, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
        .environment(\.layoutDirection, model.locale.isRTL ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Preview on the App Store"))
        .accessibilityIdentifier("storePreview")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(height: 0.5)
            .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func row(link: AppStorePreviewLink?, vertical: CGFloat = 9, @ViewBuilder content: () -> some View) -> some View {
        let part = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, vertical)
        if let link {
            Button(action: link.open) {
                part
                    .background(
                        Palette.fill1.opacity(hovered == link.title ? 1 : 0),
                        in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { inside in hover(link.title, inside) }
            .animation(MotionTiming.fast.animation, value: hovered)
            .help(String(localized: "Edit in \(link.title)"))
            .accessibilityLabel(Text(link.count > 0 ? String(localized: "Edit in \(link.title), \(link.count) suggestions") : String(localized: "Edit in \(link.title)")))
            .accessibilityIdentifier("storePreview.part.\(link.title)")
        } else {
            part
        }
    }

    /// The App Preview and screenshots: a click anywhere but on the play
    /// button opens Screenshots. Not a button around them, so the row
    /// scrolls and the play button takes its own clicks.
    @ViewBuilder
    private var shotsRow: some View {
        let part = shots()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        if let link = links?.screenshots {
            part
                .background(
                    Palette.fill1.opacity(hovered == link.title ? 1 : 0),
                    in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: link.open)
                .onHover { inside in hover(link.title, inside) }
                .animation(MotionTiming.fast.animation, value: hovered)
                .help(String(localized: "Edit in \(link.title)"))
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text(String(localized: "Edit in \(link.title)")), link.open)
                .accessibilityIdentifier("storePreview.part.\(link.title)")
        } else {
            part
        }
    }

    /// The live event's card, "Happening now" or "Upcoming"; a click opens
    /// it in In-App Events.
    @ViewBuilder
    private func eventRow(_ event: AppStoreLiveEvent) -> some View {
        let card = AppStorePreviewEventCard(event: event, label: event.isHappening ? model.words.happeningNow : model.words.upcoming)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        if let open = links?.inAppEvent {
            let title = AppWorkspaceSection.inAppEvents.title
            Button {
                open(event.id)
            } label: {
                card
                    .background(
                        Palette.fill1.opacity(hovered == title ? 1 : 0),
                        in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { inside in hover(title, inside) }
            .animation(MotionTiming.fast.animation, value: hovered)
            .help(String(localized: "Open in \(title)", comment: "kind:help"))
            .accessibilityHint(Text(String(localized: "Opens \(title)", comment: "kind:help")))
            .accessibilityIdentifier("storePreview.part.event")
        } else {
            card
        }
    }

    private func hover(_ title: String, _ inside: Bool) {
        if inside {
            hovered = title
        } else if hovered == title {
            hovered = nil
        }
    }

    private func highlighted(_ text: AppStorePreviewText, display: String? = nil) -> some View {
        Text(display ?? text.value)
            .modifier(AppStorePreviewHighlight(isOn: text.isSuggested))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIconTile(name: appName, icon: icon, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                highlighted(model.name.value.isEmpty ? AppStorePreviewText(value: appName) : model.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                highlighted(model.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Text(model.words.get)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 24)
                        .background(Self.getBlue, in: Capsule())
                    if !model.purchases.isEmpty {
                        Text(model.words.inAppPurchases)
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.label2)
                            .lineLimit(2)
                            .frame(maxWidth: 70, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: Spacing.xSmall) {
            stat(top: model.ratingCountText, big: model.ratingText, bottom: "★★★★★")
            if let age = model.ageRating {
                stat(top: String(localized: "Age"), big: age, bottom: model.words.yearsOld)
            }
            if let category = model.category {
                stat(top: String(localized: "Category"), big: nil, bottom: category)
            }
        }
    }

    private func stat(top: String, big: String?, bottom: String) -> some View {
        VStack(spacing: 1) {
            Text(top)
                .font(.caption2)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
            if let big {
                Text(big)
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.label2)
            }
            Text(bottom)
                .font(.caption2)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.promotionalText.value.isEmpty {
                highlighted(model.promotionalText)
                    .font(.system(size: 12))
                    .lineLimit(3)
            }
            highlighted(model.description, display: AppStorePreviewModel.clipped(model.description.value, to: 200))
                .font(.system(size: 12))
                .foregroundStyle(Palette.label2)
                .lineLimit(3)
            Text(model.words.more)
                .font(.caption2)
                .foregroundStyle(Self.getBlue)
        }
    }

    private var whatsNew: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.words.whatsNew)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !model.versionString.isEmpty {
                    Text(model.words.versionText(model.versionString))
                        .font(.caption2)
                        .foregroundStyle(Palette.label2)
                }
            }
            highlighted(model.whatsNew, display: AppStorePreviewModel.clipped(model.whatsNew.value, to: 160))
                .font(.system(size: 12))
                .lineLimit(3)
        }
    }

    private var purchases: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.words.inAppPurchases)
                .font(.subheadline.weight(.semibold))
            ForEach(model.purchases) { purchase in
                HStack(spacing: Spacing.small) {
                    Text(purchase.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let price = purchase.price {
                        Text(price)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label2)
                    }
                }
                .font(.system(size: 12))
            }
        }
    }
}
