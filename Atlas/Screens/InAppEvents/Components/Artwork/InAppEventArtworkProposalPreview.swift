//
//  InAppEventArtworkProposalPreview.swift
//  Atlas
//

import SwiftUI

/// A proposed card or details page as the App Store shows it, small: the
/// art with the event's badge, name and description over it. A spinner
/// while the file is read. Art the assistant just made fades in (effect 2,
/// no edge pass).
struct InAppEventArtworkProposalPreview: View {
    let path: String
    let isVideo: Bool
    let kind: InAppEventMedia.Kind
    let texts: InAppEventArtworkOverlayTexts
    /// Nil is the card 240 points wide, the details page 135.
    var preferredWidth: CGFloat?
    var identifier: String?

    @State private var phase = ImageLoadPhase.loading
    /// When the file was written: art made a moment ago arrives.
    @State private var madeAt: Date?

    var width: CGFloat { preferredWidth ?? (kind == .card ? 240 : 135) }

    var body: some View {
        let full = InAppEventArtworkOverlay.pointSize(for: kind)
        let scale = width / full.width
        ZStack(alignment: .topLeading) {
            if let image = phase.image {
                InAppEventArtworkOverlay(image: image, kind: kind, texts: texts)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: width, height: full.height * scale, alignment: .topLeading)
                    .aiArrivedImage(key: "eventArt.\(path)", arrivedAt: madeAt)
                    .transition(.opacity)
            } else {
                ImageLoadingTile(isLoading: phase.isLoading, systemImage: isVideo ? "film" : "photo")
            }
            if isVideo, phase.image != nil {
                Label("Video", systemImage: "play.fill")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.5), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
        }
        .frame(width: width, height: full.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kind.title) with “\(texts.name)” over it"))
        .accessibilityIdentifier(identifier ?? "events.media.preview.\(kind.mcpValue)")
        .task(id: path) {
            phase = .loading
            let still = await InAppEventArtworkInspector.thumbnail(URL(fileURLWithPath: path), isVideo: isVideo, maxPixel: 1280)
            guard !Task.isCancelled else { return }
            madeAt = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
            withAnimation(.easeOut(duration: 0.2)) { phase = ImageLoadPhase(finished: still) }
        }
    }
}
