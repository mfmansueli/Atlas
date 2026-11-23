//
//  PrivacyURLsTab.swift
//  Atlas
//

import SwiftUI

/// Privacy URLs: each locale's Privacy Policy URL (required) and User
/// Privacy Choices URL (optional). Unlike the worksheet these sync: an
/// edit is a Review & Push change, and the Privacy Policy URL's is the same
/// change Store Page makes.
struct PrivacyURLsTab: View {
    let viewModel: AppPrivacyViewModel
    @Environment(WorkspaceNavigator.self) private var navigator

    var body: some View {
        Group {
            switch viewModel.urls {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("Loading the privacy URLs"))
            case let .failed(message):
                AccessibilityLoadErrorView(message: message, requestLine: nil) {
                    Task { await viewModel.loadURLs() }
                }
                .padding(Spacing.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .loaded:
                if let table = viewModel.urlsTable {
                    content(table)
                }
            }
        }
        .task { if viewModel.urls.value == nil { await viewModel.loadURLs() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.urls")
    }

    private func content(_ table: PrivacyURLsTable) -> some View {
        VStack(spacing: 0) {
            // The User Privacy Choices URLs' suggestions: Accept, Dismiss and
            // the arrows; never the answers.
            if let owner = viewModel.owner, owner.showsSuggestions(on: .appPrivacy) {
                AppInformationPageBar(viewModel: owner, page: .appPrivacy)
                    .padding(.horizontal, Spacing.large)
                    .padding(.top, Spacing.small + 2)
            }
            HStack(alignment: .center, spacing: Spacing.small) {
                Text(String(localized: "\(viewModel.urlsCoverageText ?? "") · app-level fields, sent through Review & Push"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("appInformation.appPrivacy.urls.coverage")
                Button(String(localized: "Fill Missing from \(table.content.primaryLocale.name)"), action: viewModel.fillMissingPolicyURLs)
                    .disabled(table.missingPolicyLocales.allSatisfy { $0 == table.content.primaryLocale })
                    .accessibilityIdentifier("appInformation.appPrivacy.urls.fillMissing")
                Button(String(localized: "Also in Store Page ↗")) { navigator.open(.storePage) }
                    .accessibilityIdentifier("appInformation.appPrivacy.urls.storePage")
            }
            .controlSize(.regular)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small + 2)
            PrivacyURLsHeaderRow()
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    // Not lazy: a few dozen languages at most, and XCUITest's
                    // snapshot crashed SwiftUI's accessibility (label recursion)
                    // while lazy rows came and went under a suggestion card.
                    VStack(spacing: 0) {
                        ForEach(table.locales) { locale in
                            PrivacyURLsRow(table: table, locale: locale, viewModel: viewModel, isFocused: viewModel.focusedChoicesLocale == locale)
                                .id(locale.code)
                            Divider()
                        }
                    }
                }
                // The suggestion bar's arrows went to a language: its row.
                .onChange(of: viewModel.focusedChoicesLocale, initial: true) { _, locale in
                    guard let locale else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(locale.code, anchor: .center) }
                }
            }
        }
    }
}
