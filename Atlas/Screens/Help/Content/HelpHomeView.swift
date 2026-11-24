//
//  HelpHomeView.swift
//  Atlas
//

import SwiftUI

/// Atlas Help's home: search, searches to try, the four Start here
/// articles as cards, every group's articles, and Contact Support….
struct HelpHomeView: View {
    let library: HelpLibrary
    @Environment(HelpNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Atlas Help")
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("help.home.title")
            HelpSearchField(query: $navigation.query, identifier: "help.home.search")
            HStack(spacing: Spacing.xSmall) {
                Text("Try")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                ForEach(Array(HelpLibrary.tries.enumerated()), id: \.offset) { index, text in
                    Button(text) { navigation.query = text }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .accessibilityIdentifier("help.try.\(index)")
                }
            }
            group(.start) { articles in
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.small), GridItem(.flexible())], spacing: Spacing.small) {
                    ForEach(articles) { article in
                        card(article)
                    }
                }
            }
            ForEach([HelpGroup.listing, .after, .atlas]) { helpGroup in
                group(helpGroup, showsSymbol: true) { articles in
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        ForEach(articles) { article in
                            Button(article.title) { navigation.open(article.id) }
                                .buttonStyle(.link)
                                .accessibilityIdentifier("help.link.\(article.id)")
                        }
                    }
                }
            }
            Divider()
            HStack {
                Label("Still stuck? Write to us from here. Atlas attaches its version and nothing else.", systemImage: "lifepreserver")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                Spacer()
                Button("Contact Support…") { HelpSupport.contactSupport() }
                    .accessibilityIdentifier("help.contact")
            }
        }
    }

    /// A group's title, with its symbol over a list (board 49): the Start
    /// here cards carry theirs on each card.
    private func group(
        _ group: HelpGroup, showsSymbol: Bool = false, @ViewBuilder content: ([HelpArticle]) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label {
                Text(group.title)
            } icon: {
                if showsSymbol {
                    Image(systemName: group.systemImage)
                        .foregroundStyle(Palette.label2)
                }
            }
            .font(.body.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            content(library.articles(in: group))
        }
    }

    private func card(_ article: HelpArticle) -> some View {
        Button {
            navigation.open(article.id)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Label(article.title, systemImage: HelpGroup.start.systemImage)
                    .font(.body.weight(.semibold))
                Text(article.summary)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
            .contentShape(RoundedRectangle(cornerRadius: Radius.banner))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("help.card.\(article.id)")
    }
}
