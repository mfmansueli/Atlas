//
//  HelpArticleView.swift
//  Atlas
//

import SwiftUI

/// One Help article: its title and summary, its blocks, Show Me (which
/// opens that place in Atlas), the web page its steps happen on, and the
/// related articles.
struct HelpArticleView: View {
    let article: HelpArticle
    let related: [HelpArticle]
    @Environment(HelpNavigation.self) private var navigation
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(article.title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("help.article.title")
            Text(article.summary)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("help.article.summary")
            ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                HelpBlockView(block: block)
            }
            if article.showMe != nil || article.link != nil {
                HStack(spacing: Spacing.small) {
                    if let showMe = article.showMe {
                        Button {
                            show(showMe)
                        } label: {
                            Label("Show Me: \(showMe.title)", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("help.showMe")
                    }
                    if let link = article.link {
                        Button {
                            openURL(link.url)
                        } label: {
                            Label(link.title, systemImage: "arrow.up.right.square")
                        }
                        .secondaryButton()
                        .accessibilityIdentifier("help.link")
                    }
                }
            }
            if !related.isEmpty {
                Divider()
                Text("Related")
                    .font(.body.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: Spacing.small) {
                    ForEach(related) { other in
                        Button(other.title) { navigation.open(other.id) }
                            .buttonStyle(.link)
                            .accessibilityIdentifier("help.related.\(other.id)")
                    }
                }
            }
        }
    }

    private func show(_ showMe: HelpShowMe) {
        switch showMe {
        case let .settings(pane):
            SettingsNavigation.shared.pane = pane
            openSettings()
        case let .section(section):
            AtlasLifecycle.shared.open(.currentSection(section))
        case .reviewPush:
            AtlasLifecycle.shared.open(.reviewPush)
        }
        navigation.shown = String(localized: "Opened \(showMe.title) in Atlas.")
    }
}
