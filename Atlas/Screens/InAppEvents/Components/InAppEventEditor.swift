//
//  InAppEventEditor.swift
//  Atlas
//

import SwiftUI

/// The selected event: its languages, the suggestion for the one being
/// viewed, its three texts, how it did when it's over, its settings and
/// media, and the footer's one action.
struct InAppEventEditor: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent
    let onFooterAction: () -> Void

    var body: some View {
        let languages = viewModel.languages(of: event)
        let language = viewModel.selectedLanguage
        let suggestion = viewModel.suggestion
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(spacing: Spacing.small) {
                    Text(event.referenceName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("events.title")
                    let status = viewModel.status(of: event)
                    Pill(text: status.title, style: status.pillStyle)
                        .fixedSize()
                        .accessibilityIdentifier("events.status")
                }
                if languages.count > 1 || viewModel.suggestedCount > 0 {
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
                InAppEventMediaCard(
                    event: event, app: viewModel.app, proposals: viewModel.artworkProposals(of: event),
                    overlayTexts: { viewModel.overlayTexts(for: $0, of: event) },
                    onAccept: { viewModel.acceptArtwork($0) }, onDismiss: { viewModel.dismissArtwork($0) }
                )
                footer
            }
            .padding(.bottom, Spacing.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.editor")
    }

    private var analyticsURL: URL {
        URL(string: "https://appstoreconnect.apple.com/analytics/app/d30/\(viewModel.app.id)/events") ?? URL(filePath: "/")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let error = viewModel.actionError {
                InlineMessage.error(error)
                    .font(.callout)
                    .accessibilityIdentifier("events.error")
            }
            HStack(spacing: Spacing.small) {
                Text(viewModel.footerText)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("events.footer.text")
                if viewModel.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                if let button = viewModel.footerButton {
                    Button(button.title, action: onFooterAction)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!button.isEnabled)
                        .accessibilityIdentifier("events.footer.button")
                }
            }
        }
    }
}
