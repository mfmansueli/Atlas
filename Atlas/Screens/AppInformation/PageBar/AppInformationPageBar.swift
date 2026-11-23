//
//  AppInformationPageBar.swift
//  Atlas
//

import SwiftUI

/// Under a page's title: where it shows on the App Store, Accept n on This
/// Page, Accept All Pages with the total, and the ⋯ menu. A page that
/// takes no suggestions only says where it shows. Asking Claude Code is the
/// toolbar's Suggest Answers… (board 57); the request's host stays here.
struct AppInformationPageBar: View {
    @Bindable var viewModel: AppInformationViewModel
    let page: AppInformationPage

    @Environment(MCPServerController.self) private var assistants
    @Environment(AppPreferences.self) private var preferences
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            FlowLayout(spacing: Spacing.small) {
                whereShown
                if takesSuggestions {
                    if model.hereCount > 0 {
                        Button(model.acceptHereTitle) { viewModel.acceptSuggestions(onPage: page) }
                            .accessibilityIdentifier("appInformation.acceptHere")
                    }
                    acceptAll
                    if page == .appPrivacy {
                        PrivacyURLsSuggestionArrows(navigation: viewModel.privacySuggestionNavigation) { viewModel.showPrivacySuggestion($0) }
                    }
                    Text(model.restText)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                    moreMenu
                }
            }
            .overlay(alignment: .topTrailing) {
                if takesSuggestions {
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
            if takesSuggestions, page == .appPrivacy {
                privacyNote
            }
            if takesSuggestions, model.acceptsRightAway, model.totalCount > 0 {
                HStack(spacing: Spacing.small) {
                    Pill(text: String(localized: "Accepts right away"), style: .accent)
                        .fixedSize()
                    Text("Accept All Pages doesn’t ask first.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                    Button("Ask First") {
                        preferences.acceptsAllWithoutAsking = false
                        viewModel.suggestionToast = ToastMessage(text: String(localized: "Accept All shows the suggestions first again."))
                    }
                    .buttonStyle(.link)
                    .font(.subheadline)
                    .accessibilityIdentifier("appInformation.askFirst")
                }
                .padding(.leading, Spacing.xxSmall)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.pageBar")
    }

    private var takesSuggestions: Bool { viewModel.showsSuggestions(on: page) }

    private var model: AppInformationPageBarModel {
        viewModel.pageBarModel(on: page, acceptsRightAway: preferences.acceptsAllWithoutAsking)
    }

    private var whereShown: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "info.circle")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text(page.whereShown(appName: viewModel.app.name, version: viewModel.content?.version))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
        }
        .frame(minHeight: 24)
    }

    private var acceptAll: some View {
        Button {
            // One page's suggestions are free with Accept Here too.
            let accept = { viewModel.acceptAllPages(withoutAsking: preferences.acceptsAllWithoutAsking) }
            if model.otherPageCount > 0 {
                pro.require(.acceptAllPages(suggestions: model.totalCount, pages: model.otherPageCount + (model.hereCount > 0 ? 1 : 0)), then: accept)
            } else {
                accept()
            }
        } label: {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "sparkles")
                    .imageScale(.small)
                Text(model.acceptAllTitle)
                if pro.isFree, model.otherPageCount > 0 { ProChip() }
                if model.totalCount > 0 {
                    Text(SuggestionBadge.text(for: model.totalCount))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(.white.opacity(0.26), in: Capsule())
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.totalCount == 0)
        .accessibilityLabel(Text(model.acceptAllAccessibilityText))
        .accessibilityIdentifier("appInformation.acceptAll")
    }

    /// Why App Privacy's bar holds only its URLs: the answers are the
    /// person's to accept, each in the worksheet.
    private var privacyNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            Image(systemName: "lock")
                .imageScale(.small)
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("Only for User Privacy Choices URLs. You review App Privacy answers one by one in the worksheet.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appInformation.appPrivacy.barNote")
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
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityIdentifier("appInformation.more")
    }
}
