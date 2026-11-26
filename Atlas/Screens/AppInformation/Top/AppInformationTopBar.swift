//
//  AppInformationTopBar.swift
//  Atlas
//

import SwiftUI

/// The top of App Information (board 88), over the page strip: the open
/// page's sentence and, under it in blue, how many suggestions wait and
/// about how long they take; on the right Accept n on This Page
/// (secondary), Accept All Pages with the total in a purple badge
/// (primary, README-DS §4) and the ⋯ menu. Asking Claude Code is the
/// toolbar's Suggest Answers… (board 57); the request's host stays here.
struct AppInformationTopBar: View {
    @Bindable var viewModel: AppInformationViewModel

    @Environment(MCPServerController.self) private var assistants
    @Environment(AppPreferences.self) private var preferences
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        SectionHeader(subtitle: viewModel.page.summary(appName: viewModel.app.name, version: viewModel.content?.version?.versionString)) {
            if viewModel.isLoaded {
                Text(AppInformationReviewEstimate.text(for: model.totalCount))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(model.totalCount > 0 ? Palette.accentText : Palette.label2)
                    .lineLimit(1)
                    .accessibilityLabel(Text(AppInformationReviewEstimate.accessibilityText(for: model.totalCount)))
                    .accessibilityIdentifier("appInformation.estimate")
            }
        } trailing: {
            if viewModel.isLoaded {
                if takesSuggestions, model.hereCount > 0 {
                    Button(model.acceptHereTitle) { viewModel.acceptSuggestions(onPage: page) }
                        .secondaryButton()
                        .accessibilityIdentifier("appInformation.acceptHere")
                }
                acceptAll
                if takesSuggestions {
                    moreMenu
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isLoaded {
                SuggestionAskButton(
                    appID: viewModel.app.id,
                    area: .appInformation,
                    requestsAsk: $viewModel.requestsAsk,
                    prompt: viewModel.suggestionPrompt,
                    appName: viewModel.app.name,
                    onRequestFinished: { viewModel.suggestionToast = ToastMessage(text: $0) },
                    showsButton: false
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.top")
    }

    private var page: AppInformationPage { viewModel.page }

    private var takesSuggestions: Bool { viewModel.showsSuggestions(on: page) }

    private var model: AppInformationPageBarModel {
        viewModel.pageBarModel(on: page, acceptsRightAway: preferences.acceptsAllWithoutAsking)
    }

    /// Prominent while there's something to accept; once every page is
    /// reviewed a plain ✓ that says so, not a blue button that does nothing.
    @ViewBuilder
    private var acceptAll: some View {
        if model.totalCount > 0 {
            acceptAllButton.primaryButton()
        } else {
            acceptAllButton.secondaryButton()
        }
    }

    private var acceptAllButton: some View {
        Button {
            // One page's suggestions are free with Accept n on This Page too.
            let accept = { viewModel.acceptAllPages(withoutAsking: preferences.acceptsAllWithoutAsking) }
            if model.otherPageCount > 0 {
                pro.require(.acceptAllPages(suggestions: model.totalCount, pages: model.otherPageCount + (model.hereCount > 0 ? 1 : 0)), then: accept)
            } else {
                accept()
            }
        } label: {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: model.totalCount > 0 ? "sparkles" : "checkmark")
                    .imageScale(.small)
                Text(model.acceptAllTitle)
                if pro.isFree, model.otherPageCount > 0 { ProChip() }
                SuggestionBadge(count: model.totalCount)
            }
        }
        .disabled(model.totalCount == 0)
        .accessibilityLabel(Text(model.acceptAllAccessibilityText))
        .accessibilityIdentifier("appInformation.acceptAll")
    }

    /// What the More menu works on: the page, the device in view on
    /// Accessibility, every language on App Privacy.
    private var scopes: [SuggestionScope] {
        viewModel.barScopes(on: page)
    }

    private var moreMenu: some View {
        Menu {
            SuggestionsMenuItems(
                model: viewModel.suggestionBar(for: scopes, assistant: assistants.assistantStatus.clientName),
                filter: $viewModel.suggestionFilter,
                showsOnlyFields: $viewModel.showsOnlySuggestedFields,
                // Accessibility and Privacy URLs always show every row.
                showsFieldsToggle: page != .accessibility && page != .appPrivacy,
                onDismissAll: { viewModel.dismissAllSuggestions(in: scopes) },
                onRestore: { viewModel.restoreDismissedSuggestions(in: scopes) }
            )
        } label: {
            Label(String(localized: "More", comment: "kind:button · App Information's suggestions menu"), systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .pageControlSize()
        .fixedSize()
        .help(Text("More", comment: "kind:tooltip · App Information's suggestions menu"))
        .accessibilityIdentifier("appInformation.more")
    }
}
