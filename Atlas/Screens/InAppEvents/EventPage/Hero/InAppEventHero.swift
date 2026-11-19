//
//  InAppEventHero.swift
//  Atlas
//

import SwiftUI

/// The first card of an event's page (board 40): "On the App Store" with
/// the concept previewed (or the event's own art) under the text of the
/// language being written, and the Artwork panel beside it, under it when
/// the page is narrower than 700 points.
struct InAppEventHero: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent
    let flow: EventArtworkFlow?
    var isStacked = false
    let actions: EventArtworkPanelActions

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        let locale = viewModel.localeCode
        let concept = flow?.previewConcept
        let state = viewModel.artworkPanel(of: event, flow: flow)
        let texts = viewModel.shownTexts(of: event, locale: locale)
        let preview = InAppEventStorePreview(
            app: viewModel.app, event: event, kind: $viewModel.previewKind,
            card: source(.card, concept: concept, locale: locale), details: source(.details, concept: concept, locale: locale),
            texts: texts,
            note: InAppEventPreviewNote.make(
                previewing: previewingName(concept, state: state), texts: texts, primaryLocale: event.primaryLocale,
                kind: viewModel.previewKind, appName: viewModel.app.name
            ),
            isStacked: isStacked, now: viewModel.now()
        ) { kind in
            actions.view(concept?.id, kind)
        }
        let panel = EventArtworkPanel(
            state: state, event: event, card: viewModel.artSource(.card, of: event, locale: locale),
            details: viewModel.artSource(.details, of: event, locale: locale), locale: flow?.run.primaryLocale,
            isFree: pro.isFree, isWorking: flow?.isWorking ?? false, problem: flow?.problem, copiedPrompt: flow?.copiedPrompt,
            onCopyAgain: { if let prompt = flow?.copiedPrompt { flow?.copy(prompt) } },
            actions: actions
        )
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    preview
                    panel
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.large) {
                    preview
                    panel
                        .frame(width: 292)
                }
            }
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("On the App Store, and the artwork"))
        .accessibilityIdentifier("events.hero")
    }

    /// The concept's image of `kind`, else the event's own.
    private func source(_ kind: InAppEventMedia.Kind, concept: EventArtworkConcept?, locale: String) -> InAppEventArtSource {
        if let still = concept?.still(kind, locale: locale), still.kind == kind { return InAppEventArtSource(still) }
        return viewModel.artSource(kind, of: event, locale: locale)
    }

    /// The concept's name while the preview shows one that isn't in use.
    private func previewingName(_ concept: EventArtworkConcept?, state: EventArtworkPanelState) -> String? {
        guard let concept, let run = flow?.run else { return nil }
        let usedIsCurrent = switch state.phase {
        case .used, .complete, .changing: true
        default: false
        }
        return concept.id == run.usedConceptID && usedIsCurrent ? nil : concept.name
    }
}
