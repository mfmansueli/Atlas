//
//  HelpTopBar.swift
//  Atlas
//

import SwiftUI

/// Back, and where you are in Atlas Help.
struct HelpTopBar: View {
    let library: HelpLibrary
    @Environment(HelpNavigation.self) private var navigation

    var body: some View {
        HStack(spacing: Spacing.small) {
            Button {
                navigation.back()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!navigation.canGoBack)
            .accessibilityLabel(Text("Back"))
            .accessibilityIdentifier("help.back")
            Text(crumb)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .accessibilityIdentifier("help.crumb")
            Spacer()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
    }

    /// "Atlas Help", "Search", "Atlas Help › Start here › Connect App Store
    /// Connect".
    private var crumb: String {
        switch navigation.place {
        case .home: String(localized: "Atlas Help")
        case .search: String(localized: "Atlas Help › Search")
        case let .article(id):
            library.article(id).map { String(localized: "Atlas Help › \($0.group.title) › \($0.title)") } ?? String(localized: "Atlas Help")
        }
    }
}
