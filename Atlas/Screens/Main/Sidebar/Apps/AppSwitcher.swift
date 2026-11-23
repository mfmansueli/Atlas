//
//  AppSwitcher.swift
//  Atlas
//

import SwiftUI

/// The top of the sidebar (board 63): the app being viewed and its team
/// beside a round chevron, opening the app menu (also ⌘K). A last line
/// says how many other apps there are and, in purple, which have
/// suggestions waiting. The tour's first tip points at it.
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
    @State private var isHovered = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .help("Switch app  ⌘K")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary.accessibilityLabel(appName: viewModel.selectedApp?.name)))
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
        // The tour's first tip, pointing at the app's row.
        .tourTip(.apps, arrowEdge: .trailing, anchor: summary.hasOthers ? .point(UnitPoint(x: 1, y: 0.32)) : .rect(.bounds))
    }

    private var label: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        return VStack(spacing: 0) {
            HStack(spacing: 9) {
                if let app = viewModel.selectedApp {
                    AppIconTile(name: app.name, icon: app.icon, size: 30)
                } else {
                    SkeletonBlock(width: 30, height: 30, cornerRadius: Radius.menuRow)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.selectedApp?.name ?? String(localized: "No app"))
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(teamLine)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The round control that says the switcher opens a menu.
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label)
                    .frame(width: 22, height: 22)
                    .background(Palette.raised, in: Circle())
                    .depth(.card)
                    .overlay(Circle().strokeBorder(Palette.separator, lineWidth: 0.5))
            }
            .frame(minHeight: 46)
            if summary.hasOthers {
                othersLine
            }
        }
        .padding(.horizontal, Spacing.small)
        .background(isHovered ? Palette.fill2 : Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .contentShape(shape)
        .onHover { isHovered = $0 }
    }

    /// "5 other apps · 2 with suggestions", the suggestions in purple.
    private var othersLine: some View {
        let others = Text(summary.othersText).foregroundStyle(Palette.label2)
        let suggestions = Text(summary.suggestionsText).foregroundStyle(Palette.ai).fontWeight(.semibold)
        return Text("\(others)\(suggestions)")
            .font(.subheadline)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Palette.separator)
                    .frame(height: 0.5)
            }
    }

    private var current: TeamAccount? {
        accounts.first { $0.id == currentAccountID }
    }

    /// "Northpier Studio · Admin".
    private var teamLine: String {
        guard let current else { return String(localized: "No key") }
        return "\(current.name) · \(current.role)"
    }

    /// The last line, from every other app's count.
    private var summary: AppSwitcherSummary {
        AppSwitcherSummary(others: viewModel.apps.filter { $0.id != viewModel.selectedAppID }.map { app in
            (name: app.name, suggestionCount: indicators(app).suggestionCount)
        })
    }
}
