//
//  AppSwitcher.swift
//  Atlas
//

import SwiftUI

/// The top of the sidebar: the app being viewed and its team, opening the
/// app menu. A small purple dot says other apps have suggestions waiting.
struct AppSwitcher: View {
    @Bindable var viewModel: AppListViewModel
    let accounts: [TeamAccount]
    let currentAccountID: TeamAccount.ID?
    let indicators: (StoreApp) -> AppIndicators
    var onSelectAccount: (TeamAccount) -> Void = { _ in }
    var onAddKey: () -> Void = {}
    /// Opens the menu right away (a DEBUG scene).
    var startsOpen = false

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(Text(teamLine))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sidebar.appSwitcher")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AppSwitcherMenu(
                viewModel: viewModel, accounts: accounts, currentAccountID: currentAccountID, indicators: indicators,
                onSelectApp: { app in
                    isPresented = false
                    viewModel.selectedAppID = app.id
                },
                onSelectAccount: { account in
                    isPresented = false
                    onSelectAccount(account)
                },
                onAddKey: {
                    isPresented = false
                    onAddKey()
                }
            )
        }
        .task {
            if startsOpen { isPresented = true }
        }
    }

    private var label: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return HStack(spacing: 9) {
            if let app = viewModel.selectedApp {
                AppIconTile(name: app.name, icon: app.icon, size: 30)
            } else {
                SkeletonBlock(width: 30, height: 30, cornerRadius: 7)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.selectedApp?.name ?? String(localized: "No app"))
                    .font(.headline)
                    .lineLimit(1)
                Text(teamLine)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if othersHaveSuggestions {
                Circle()
                    .fill(Palette.suggestionBadge)
                    .frame(width: 8, height: 8)
                    .help("Other apps have suggestions")
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.label2)
        }
        .padding(.horizontal, Spacing.small)
        .frame(height: 48)
        .background(Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .contentShape(shape)
    }

    private var current: TeamAccount? {
        accounts.first { $0.id == currentAccountID }
    }

    /// "Northpier Studio · Admin".
    private var teamLine: String {
        guard let current else { return String(localized: "No key") }
        return "\(current.name) · \(current.role)"
    }

    private var othersHaveSuggestions: Bool {
        viewModel.apps.contains { $0.id != viewModel.selectedAppID && indicators($0).suggestionCount > 0 }
    }

    /// "App: Lumen Journal. Switch app".
    private var accessibilityText: String {
        guard let app = viewModel.selectedApp else { return String(localized: "Switch app") }
        return othersHaveSuggestions
            ? String(localized: "App: \(app.name). Switch app. Other apps have suggestions")
            : String(localized: "App: \(app.name). Switch app")
    }
}
