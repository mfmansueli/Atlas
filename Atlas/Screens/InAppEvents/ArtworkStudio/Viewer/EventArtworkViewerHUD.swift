//
//  EventArtworkViewerHUD.swift
//  Atlas
//

import SwiftUI

/// The pill over the image in full screen: ‹, the concept's name, "1 of
/// 3", ›, Use This Artwork and Exit Full Screen.
struct EventArtworkViewerHUD: View {
    @Bindable var flow: EventArtworkFlow
    let onUse: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            if flow.viewerCanStep {
                EventArtworkViewerButton(
                    systemImage: "chevron.left", shape: .circle(28), label: String(localized: "Previous concept"),
                    help: String(localized: "Previous  ←"), identifier: "events.art.viewer.hud.previous"
                ) {
                    flow.stepViewer(-1)
                }
            }
            Text(flow.viewerTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let position = flow.viewerPosition, position.count > 1 {
                Text("\(position.index) of \(position.count)")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
            }
            if flow.viewerCanStep {
                EventArtworkViewerButton(
                    systemImage: "chevron.right", shape: .circle(28), label: String(localized: "Next concept"),
                    help: String(localized: "Next  →"), identifier: "events.art.viewer.hud.next"
                ) {
                    flow.stepViewer(1)
                }
            }
            if flow.viewerConcept != nil, !flow.viewerIsUsed {
                EventArtworkViewerButton(
                    title: String(localized: "Use This Artwork"), isProminent: true, label: String(localized: "Use This Artwork"),
                    help: String(localized: "Both images go to Review & Push, for every language"), identifier: "events.art.viewer.hud.use",
                    action: onUse
                )
                .disabled(!flow.viewerCanUse)
            }
            EventArtworkViewerButton(
                title: String(localized: "Exit Full Screen"), label: String(localized: "Exit Full Screen"),
                help: String(localized: "Exit Full Screen  esc"), identifier: "events.art.viewer.hud.exit", action: onExit
            )
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 6)
        .background(EventArtworkViewerStyle.panel, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.viewer.hud")
    }
}
