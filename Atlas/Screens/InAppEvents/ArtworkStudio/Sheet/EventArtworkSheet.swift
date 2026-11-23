//
//  EventArtworkSheet.swift
//  Atlas
//

import SwiftUI

/// "Artwork for Winter Reflection Challenge" (board 47), the only sheet:
/// the Brief. Make the Artwork starts the run and closes it at once; the
/// concepts fill in on the event's page. 940 points wide, less in a
/// smaller window, up to 720 tall.
struct EventArtworkSheet: View {
    @Bindable var flow: EventArtworkFlow
    var width: CGFloat = 940
    var height: CGFloat = 720
    /// The Pro gate around Make the Artwork.
    var onMake: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Artwork for \(flow.event.referenceName)")
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("events.art.title")
                Text("Claude makes the event card and the event details image as a matching pair. They are drawn while you keep working.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .accessibilityIdentifier("events.art.subtitle")
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            Divider()
            ScrollView {
                EventArtworkBriefStep(flow: flow)
                    .padding(Spacing.xLarge)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            Divider()
            EventArtworkFooter(flow: flow, onMake: onMake)
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.sheet")
    }
}
