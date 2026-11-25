//
//  EventArtworkViewerStage.swift
//  Atlas
//

import SwiftUI

/// The middle of the viewer: the card or details image as large as fits
/// with nothing cropped, the App Store's text over it at that size, where
/// that text goes, "▶ 0:20" and the loop when it moves, a shimmer while
/// Claude redraws it, and the arrows to the other concepts.
struct EventArtworkViewerStage: View {
    @Bindable var flow: EventArtworkFlow
    let viewer: EventArtworkViewer
    let event: InAppEvent
    let texts: InAppEventArtworkOverlayTexts
    /// The app's icon in the card's App Store row.
    var appIcon: AppIcon?
    /// The event's own image of the kind shown, for an event without concepts.
    let ownSource: InAppEventArtSource
    let loopPlayer: AppPreviewPlayerModel

    var body: some View {
        HStack(spacing: Spacing.medium) {
            if flow.viewerCanStep, !viewer.isFull {
                arrow(-1)
            }
            GeometryReader { proxy in
                let size = Self.fit(viewer.kind, in: proxy.size)
                image(size: size)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            if flow.viewerCanStep, !viewer.isFull {
                arrow(1)
            }
        }
        .padding(.horizontal, viewer.isFull ? 0 : 14)
        .padding(.vertical, viewer.isFull ? 0 : Spacing.large)
    }

    /// As large as fits in `box`, nothing cropped.
    static func fit(_ kind: InAppEventMedia.Kind, in box: CGSize) -> CGSize {
        let ratio: CGFloat = kind == .card ? 16 / 9 : 9 / 16
        let width = max(1, min(box.width, box.height * ratio))
        return CGSize(width: width, height: width / ratio)
    }

    private var cornerRadius: CGFloat { viewer.isFull ? 0 : 14 }

    @ViewBuilder
    private func image(size: CGSize) -> some View {
        let video = flow.viewerVideo(viewer.kind)
        let still = flow.viewerStill(viewer.kind)
        let source: InAppEventArtSource = flow.viewerConcept == nil ? ownSource : InAppEventArtSource(still)
        ZStack {
            if let video {
                EventArtworkViewerLoop(model: loopPlayer, url: URL(fileURLWithPath: video.path), posterPath: still?.isVideo == false ? still?.path : nil)
            } else if source.exists {
                InAppEventArtwork(event: event, source: source, cornerRadius: 0, maxPixel: 3840)
            } else {
                missing
            }
            if viewer.showsText, source.exists || video != nil {
                InAppEventArtworkTextLayer(
                    kind: viewer.kind, texts: texts, scale: size.width / InAppEventArtworkOverlay.pointSize(for: viewer.kind).width,
                    when: InAppEventWhenText.text(for: event), appIcon: appIcon
                )
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("events.art.viewer.storeText")
            }
            if viewer.showsTextArea {
                InAppEventTextAreaHatch(labelSize: max(11, size.height * 0.022))
            }
            if flow.viewerIsRevising {
                redrawing(size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if !viewer.isFull {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if video != nil {
                Label("0:\(AutopilotArtworkMotion.loopSeconds)", systemImage: "play.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, size.height * 0.026)
                    .padding(.trailing, size.width * 0.016)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("events.art.viewer.motion")
            }
        }
        .depth(viewer.isFull ? .flat : .sheet)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.viewer.image.\(viewer.conceptID ?? "event").\(viewer.kind.mcpValue)")
    }

    private var missing: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: StatusSymbol.needsYou.symbol)
                .font(.largeTitle)
                .foregroundStyle(Palette.warn)
            Text(viewer.kind == .card ? "No event card yet" : "No event details image yet")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.06))
    }

    private func redrawing(_ size: CGSize) -> some View {
        ZStack {
            SkeletonBlock(width: size.width, height: size.height, cornerRadius: 0)
                .opacity(0.5)
            Text("Claude is changing this concept…")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityIdentifier("events.art.viewer.busy")
        }
        .allowsHitTesting(false)
    }

    private func arrow(_ offset: Int) -> some View {
        EventArtworkViewerButton(
            systemImage: offset < 0 ? "chevron.left" : "chevron.right", shape: .circle(36),
            label: offset < 0 ? String(localized: "Previous concept") : String(localized: "Next concept"),
            help: offset < 0 ? String(localized: "Previous  ←") : String(localized: "Next  →"),
            identifier: offset < 0 ? "events.art.viewer.previous" : "events.art.viewer.next"
        ) {
            flow.stepViewer(offset)
        }
    }
}
