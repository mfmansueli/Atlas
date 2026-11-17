//
//  InAppEventPreview.swift
//  Atlas
//

import SwiftUI

/// The event's card as people see it on the App Store in the language
/// being viewed: the image, the badge, the name, the short description
/// and when it starts. While a suggestion waits it shows the suggestion,
/// and says so.
struct InAppEventPreview: View {
    let app: StoreApp
    let event: InAppEvent
    let name: String
    let shortDescription: String
    let isRightToLeft: Bool
    /// "Showing the suggestion. Until you accept it, people who read
    /// German see English." or "Showing German".
    let note: String
    let showsSuggestion: Bool
    var now = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("On the App Store")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 2) {
                InAppEventArtwork(event: event, cornerRadius: 11)
                    .frame(height: 144)
                Text((event.badge?.title ?? "").uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Palette.label2)
                    .padding(.top, Spacing.small)
                    .padding(.horizontal, Spacing.xxSmall)
                Group {
                    Text(name.isEmpty ? event.referenceName : name)
                        .font(.system(size: 16, weight: .bold))
                        .accessibilityIdentifier("events.preview.name")
                    Text(shortDescription)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("events.preview.short")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xxSmall)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                Text(whenText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accentText)
                    .padding(.horizontal, Spacing.xxSmall)
                    .padding(.top, 2)
                    .padding(.bottom, Spacing.xxSmall)
                HStack(spacing: Spacing.small) {
                    AppIconTile(name: app.name, icon: app.icon, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text("In-app purchases")
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Get")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accentText)
                        .padding(.horizontal, Spacing.medium)
                        .frame(height: 24)
                        .background(Palette.fill2, in: Capsule())
                }
            }
            .padding(Spacing.small)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
            .accessibilityElement(children: .contain)
            Text(note)
                .font(.caption)
                .foregroundStyle(showsSuggestion ? Palette.machineTranslated : Palette.label2)
                .accessibilityIdentifier("events.preview.note")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.preview")
    }

    /// "Starts Dec 1", "Now available", "Ended".
    private var whenText: String {
        guard let start = event.schedule?.eventStart, let end = event.schedule?.eventEnd else { return String(localized: "No dates yet") }
        if event.state.isOver || end < now { return String(localized: "Ended") }
        if start <= now { return String(localized: "Now available") }
        return String(localized: "Starts \(start.formatted(.dateTime.month(.abbreviated).day()))")
    }
}
