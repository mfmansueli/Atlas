//
//  HelpSearchResultsView.swift
//  Atlas
//

import SwiftUI

/// What a search found: each article with its group and summary, or what
/// to try when nothing matches.
struct HelpSearchResultsView: View {
    let query: String
    let results: [HelpArticle]
    @Environment(HelpNavigation.self) private var navigation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(Self.heading(count: results.count, query: query))
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("help.results.title")
            if results.isEmpty {
                Text("Nothing in Help matches that. Try fewer words, or write to us: Help → Contact Support…")
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("help.results.none")
            }
            ForEach(results) { article in
                Button {
                    navigation.open(article.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(article.title)
                                .font(.body.weight(.semibold))
                            Text(article.group.title)
                                .font(.caption)
                                .foregroundStyle(Palette.label2)
                        }
                        Text(article.summary)
                            .font(.callout)
                            .foregroundStyle(Palette.label2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.small)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("help.result.\(article.id)")
            }
        }
    }

    /// "2 results for “vendor”".
    static func heading(count: Int, query: String) -> String {
        switch count {
        case 0: String(localized: "No results for “\(query)”")
        case 1: String(localized: "1 result for “\(query)”")
        default: String(localized: "\(count) results for “\(query)”")
        }
    }
}
