//
//  EventArtworkViewerTopBar.swift
//  Atlas
//

import SwiftUI

/// The viewer's top bar: room for the window's traffic lights, Close, the
/// concept's name over "Concept 1 of 3 · Claude · Event card ·
/// 1920 × 1080", Event Card | Event Details, the App Store Text and Text
/// Area switches, and Enter Full Screen.
struct EventArtworkViewerTopBar: View {
    @Bindable var flow: EventArtworkFlow
    let viewer: EventArtworkViewer
    var isNarrow = false
    let onClose: () -> Void
    let onFullScreen: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 10) {
            // The window's own traffic lights sit here.
            Color.clear
                .frame(width: 60, height: 1)
            EventArtworkViewerButton(
                systemImage: "xmark", shape: .circle(28), label: String(localized: "Close"), help: String(localized: "Close  esc"),
                identifier: "events.art.viewer.close", action: onClose
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(flow.viewerTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .accessibilityIdentifier("events.art.viewer.title")
                Text(flow.viewerSubtitle)
                    .font(.callout)
                    .foregroundStyle(EventArtworkViewerStyle.secondary(contrast))
                    .lineLimit(1)
                    .accessibilityIdentifier("events.art.viewer.subtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            EventArtworkViewerSegments(kind: Binding { flow.viewer?.kind ?? .card } set: { flow.setViewerKind($0) })
            EventArtworkViewerToggle(
                title: String(localized: "App Store Text"),
                isOn: Binding { flow.viewer?.showsText ?? true } set: { flow.viewer?.showsText = $0 },
                help: String(localized: "Show the name and description the App Store puts over the image"),
                identifier: "events.art.viewer.text", isNarrow: isNarrow
            )
            EventArtworkViewerToggle(
                title: String(localized: "Text Area"),
                isOn: Binding { flow.viewer?.showsTextArea ?? false } set: { flow.viewer?.showsTextArea = $0 },
                help: String(localized: "Show the area the App Store’s text covers"),
                identifier: "events.art.viewer.textArea", isNarrow: isNarrow
            )
            EventArtworkViewerButton(
                systemImage: "arrow.up.left.and.arrow.down.right", shape: .circle(28), label: String(localized: "Enter full screen"),
                help: String(localized: "Enter Full Screen  ⌃⌘F"), identifier: "events.art.viewer.full", action: onFullScreen
            )
        }
        .padding(.leading, Spacing.large)
        .padding(.trailing, 14)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EventArtworkViewerStyle.hairline(contrast)).frame(height: 0.5)
        }
    }
}
