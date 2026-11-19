//
//  HelpSidebar.swift
//  Atlas
//

import SwiftUI

/// Atlas Help's sidebar: Search Help, the home page, and every article by
/// group.
struct HelpSidebar: View {
    let library: HelpLibrary
    @Environment(HelpNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        VStack(alignment: .leading, spacing: 0) {
            HelpSearchField(query: $navigation.query, identifier: "help.search")
                .padding(Spacing.small)
            List {
                row(String(localized: "Atlas Help"), systemImage: "book", isSelected: navigation.place == .home, id: "help.nav.home") {
                    navigation.goHome()
                }
                ForEach(HelpGroup.allCases) { group in
                    Section(group.title) {
                        ForEach(library.articles(in: group)) { article in
                            row(article.title, isSelected: navigation.place == .article(article.id), id: "help.nav.\(article.id)") {
                                navigation.open(article.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 230)
    }

    private func row(
        _ title: String, systemImage: String? = nil, isSelected: Bool, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, Spacing.xSmall)
            .background(isSelected ? Palette.fill2 : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
