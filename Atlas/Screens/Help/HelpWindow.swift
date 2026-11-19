//
//  HelpWindow.swift
//  Atlas
//

import SwiftUI

/// Atlas Help (board 49), opened with ⌘? or the Help menu: the articles
/// in a sidebar with search, and home, search results or an article,
/// with Back and where you are.
struct HelpWindow: View {
    @Environment(HelpNavigation.self) private var navigation
    var library = HelpLibrary.shared

    var body: some View {
        HStack(spacing: 0) {
            HelpSidebar(library: library)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HelpTopBar(library: library)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        if let shown = navigation.shown {
                            HelpShownBanner(text: shown)
                        }
                        content
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(Spacing.xLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(navigation.place)
            }
        }
        .frame(minWidth: 760, idealWidth: 900, minHeight: 520, idealHeight: 640)
        .background(Palette.content)
        // Without .contain the window's identifier replaces its rows'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("help.window")
    }

    @ViewBuilder private var content: some View {
        switch navigation.place {
        case .home:
            HelpHomeView(library: library)
        case let .search(query):
            HelpSearchResultsView(query: query, results: library.search(query))
        case let .article(id):
            if let article = library.article(id) {
                HelpArticleView(article: article, related: library.related(to: article))
            } else {
                HelpHomeView(library: library)
            }
        }
    }
}
