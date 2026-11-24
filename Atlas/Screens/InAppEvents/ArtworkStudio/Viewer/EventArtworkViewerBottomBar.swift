//
//  EventArtworkViewerBottomBar.swift
//  Atlas
//

import SwiftUI

/// The viewer's bottom bar: the concepts as a film (the one used with a
/// green check), why it was drawn this way and its checks, the language of
/// the App Store's text, Ask for Changes…, and Use This Artwork or "✓ In
/// use".
struct EventArtworkViewerBottomBar: View {
    @Bindable var flow: EventArtworkFlow
    let viewer: EventArtworkViewer
    let locales: [String]
    var isNarrow = false
    let onUse: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if !flow.viewerConcepts.isEmpty {
                film
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(flow.viewerWhy)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .accessibilityIdentifier("events.art.viewer.why")
                if !isNarrow {
                    Text(flow.viewerChecks)
                        .font(.callout)
                        .foregroundStyle(EventArtworkViewerStyle.secondary(contrast))
                        .lineLimit(1)
                        .accessibilityIdentifier("events.art.viewer.checks")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if viewer.showsText, locales.count > 1 {
                languages
            }
            if flow.viewerConcept != nil {
                EventArtworkViewerButton(
                    title: String(localized: "Ask for Changes…"), label: String(localized: "Ask for Changes…"),
                    help: String(localized: "Tell Claude what to change in this pair"), identifier: "events.art.viewer.ask"
                ) {
                    flow.openAsk()
                }
                .disabled(!flow.viewerCanAsk || viewer.isAsking)
                if flow.viewerIsUsed {
                    Text("✓ In use")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(EventArtworkViewerStyle.inUse)
                        .accessibilityIdentifier("events.art.viewer.inUse")
                } else {
                    EventArtworkViewerButton(
                        title: String(localized: "Use This Artwork"), isProminent: true, label: String(localized: "Use This Artwork"),
                        help: String(localized: "Both images go to Review & Push, for every language"), identifier: "events.art.viewer.use",
                        action: onUse
                    )
                    .disabled(!flow.viewerCanUse)
                }
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(EventArtworkViewerStyle.hairline(contrast)).frame(height: 0.5)
        }
    }

    private var film: some View {
        HStack(spacing: 6) {
            ForEach(flow.viewerConcepts) { concept in
                thumbnail(concept)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Concepts"))
        .accessibilityIdentifier("events.art.viewer.film")
    }

    private func thumbnail(_ concept: EventArtworkConcept) -> some View {
        let isOn = concept.id == viewer.conceptID
        let height: CGFloat = isNarrow ? 32 : 46
        let width = viewer.kind == .card ? height * 16 / 9 : height * 9 / 16
        let still = concept.still(viewer.kind, locale: viewer.locale)
        return Button {
            flow.showInViewer(concept.id)
        } label: {
            Group {
                if let still, still.kind == viewer.kind {
                    InAppEventArtworkThumbnailFill(path: still.path, isVideo: still.isVideo, maxPixel: 240)
                } else {
                    Color.white.opacity(0.1)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
            .padding(2)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
                    .strokeBorder(isOn ? .white : .white.opacity(0.25), lineWidth: isOn ? 2 : 1)
            )
            .opacity(isOn || contrast == .increased ? 1 : 0.78)
            .overlay(alignment: .topTrailing) {
                if concept.id == flow.run.usedConceptID {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(EventArtworkViewerStyle.inUse, in: Circle())
                        .offset(x: 4, y: -4)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(concept.name)
        .accessibilityLabel(Text(concept.name))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("events.art.viewer.film.\(concept.id)")
    }

    /// The language of the App Store's text: the one language picker
    /// (README-DS §12), compact, dark like the viewer.
    @ViewBuilder
    private var languages: some View {
        if let model = LanguageBarModel.plain(codes: locales, current: viewer.locale) {
            LanguagePickerButton(model: model, style: .compact, identifier: "events.art.viewer.language") { locale in
                flow.viewer?.locale = locale.code
            }
            .environment(\.colorScheme, .dark)
        }
    }
}
