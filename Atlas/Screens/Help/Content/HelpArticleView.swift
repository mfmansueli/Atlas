//
//  HelpArticleView.swift
//  Atlas
//

import SwiftUI

/// One Help article: its title and summary, its blocks, Show Me (which
/// opens that place in Atlas) and the related articles.
struct HelpArticleView: View {
    let article: HelpArticle
    let related: [HelpArticle]
    @Environment(HelpNavigation.self) private var navigation
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(article.title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("help.article.title")
            Text(article.summary)
                .font(.title3)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("help.article.summary")
            ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                HelpBlockView(block: block)
            }
            if let showMe = article.showMe {
                Button("Show Me: \(showMe.title)") { show(showMe) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("help.showMe")
            }
            if !related.isEmpty {
                Divider()
                Text("Related")
                    .font(.headline)
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
