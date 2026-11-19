//
//  InAppEventPage.swift
//  Atlas
//

import SwiftUI

/// One event's page (board 40), a column at most 780 wide: the preview
/// and its artwork, the languages, the suggestion for the one being
/// written, the three texts, how it did once it's over, its settings, art
/// an assistant proposed, and what it still needs.
struct InAppEventPage: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent
    let flow: EventArtworkFlow?
    let actions: EventArtworkPanelActions

    @State private var width: CGFloat = 900

    var body: some View {
        let languages = viewModel.languages(of: event)
        let language = viewModel.selectedLanguage
        let suggestion = viewModel.suggestion
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                InAppEventHero(viewModel: viewModel, event: event, flow: flow, isStacked: width < 700, actions: actions)
                if event.state.isEditable, languages.count > 1 || viewModel.suggestedCount > 0 {
                    InAppEventLanguageBar(viewModel: viewModel, languages: languages)
                }
                if let suggestion {
                    InAppEventSuggestionCard(
                        languageName: language?.name ?? suggestion.locale, suggestion: suggestion, fallbackNote: viewModel.fallbackNote,
                        onDismiss: { viewModel.dismissSuggestion() }, onAccept: { viewModel.acceptSuggestion() }
                    )
                } else if let note = viewModel.fallbackNote {
                    InlineMessage(text: note, systemImage: "globe", tint: Palette.label2)
                        .font(.callout)
                        .accessibilityIdentifier("events.fallback")
                }
                ForEach(InAppEventField.allCases) { field in
                    InAppEventFieldBox(
                        field: field,
                        text: Binding { viewModel.text(field) } set: { viewModel.edit(field, to: $0) },
                        placeholder: viewModel.fallbackText(field),
                        suggested: suggestion?.text(field),
                        isEditable: viewModel.canEdit,
                        isPending: viewModel.isPending(field),
                        isRightToLeft: language?.isRightToLeft ?? false
                    )
                }
                if event.state.isOver {
                    InAppEventResultsCard(results: viewModel.results[event.id], analyticsURL: analyticsURL)
                }
                InAppEventSettingsCard(rows: viewModel.settings(of: event))
                let proposals = viewModel.artworkProposals(of: event).filter { proposal in
                    !viewModel.isFromUsedArtwork(proposal, of: event)
                }
                if !proposals.isEmpty {
                    InAppEventMediaCard(
                        event: event, app: viewModel.app, proposals: proposals,
                        overlayTexts: { viewModel.overlayTexts(for: $0, of: event) },
                        onAccept: { viewModel.acceptArtwork($0) }, onDismiss: { viewModel.dismissArtwork($0) }
                    )
                }
                if let error = viewModel.actionError {
                    InlineMessage.error(error)
                        .font(.callout)
                        .accessibilityIdentifier("events.error")
                }
                Text(viewModel.footerText)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.footer.text")
            }
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.large)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.editor")
    }

    private var analyticsURL: URL {
        URL(string: "https://appstoreconnect.apple.com/analytics/app/d30/\(viewModel.app.id)/events") ?? URL(filePath: "/")
    }
}
