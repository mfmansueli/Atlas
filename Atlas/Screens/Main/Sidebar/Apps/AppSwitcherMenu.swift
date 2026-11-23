//
//  AppSwitcherMenu.swift
//  Atlas
//

import SwiftUI

/// The app menu: every app of the account with its count, search and sort
/// when there are many, Add App… and Switch Account or Key…, and when the
/// list was synced.
struct AppSwitcherMenu: View {
    @Bindable var viewModel: AppListViewModel
    let accounts: [TeamAccount]
    let currentAccountID: TeamAccount.ID?
    let indicators: (StoreApp) -> AppIndicators
    let onSelectApp: (StoreApp) -> Void
    /// Add App…: the team's apps the menu doesn't show yet.
    let onAddApp: () -> Void
    /// Switch Account or Key…: Accounts and keys.
    let onShowAccounts: () -> Void

    @Environment(ProGate.self) private var pro: ProGate?

    /// More apps than this get a search field.
    static let searchThreshold = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .padding(.horizontal, Spacing.medium)
                .padding(.top, 10)
                .padding(.bottom, Spacing.xSmall)
            if viewModel.apps.count > Self.searchThreshold {
                TextField("Name, bundle ID or SKU", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Spacing.small)
                    .padding(.bottom, Spacing.xSmall)
                    .accessibilityIdentifier("sidebar.appSearch")
            }
            apps
            Divider()
                .padding(.vertical, Spacing.xxSmall)
            accountMenu
            footer
        }
        .frame(width: 280)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar.appMenu")
    }

    /// "Northpier Studio · App Store Connect".
    private var header: String {
        let team = accounts.first { $0.id == currentAccountID }?.name
        return team.map { String(localized: "\($0) · App Store Connect") } ?? String(localized: "App Store Connect")
    }

    @ViewBuilder
    private var apps: some View {
        let visible = viewModel.sortedVisibleApps(indicators: indicators)
        if visible.isEmpty {
            Text(viewModel.searchText.isEmpty ? String(localized: "No apps") : String(localized: "No app matches “\(viewModel.searchText)”"))
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        } else {
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(visible) { app in
                        AppSwitcherRow(
                            app: app,
                            indicators: indicators(app),
                            isCurrent: app.id == viewModel.selectedAppID,
                            isLocked: pro?.isLocked(appID: app.id) ?? false
                        ) {
                            onSelectApp(app)
                        }
                        .accessibilityIdentifier("sidebar.app.\(app.id)")
                    }
                }
                .padding(.horizontal, Spacing.xSmall)
            }
            .frame(maxHeight: 368)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Add App… and Switch Account or Key… (Redesign, 23 November): each
    /// opens its sheet, Add App and Accounts and keys.
    private var accountMenu: some View {
        VStack(spacing: 0) {
            MenuItem(title: String(localized: "Add App…", comment: "kind:menu-item"), action: onAddApp)
                .accessibilityIdentifier("sidebar.addApp")
            MenuItem(title: String(localized: "Switch Account or Key…", comment: "kind:menu-item"), action: onShowAccounts)
                .accessibilityIdentifier("sidebar.accountSwitcher")
        }
        .padding(.horizontal, Spacing.xSmall)
    }

    /// A row under the apps that opens a sheet, highlighted on hover.
    private struct MenuItem: View {
        let title: String
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xSmall)
                    .frame(height: 28)
                    .background(isHovered ? Palette.fill1 : .clear, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            // "synced 2 min. ago" moves on as time passes.
            TimelineView(.everyMinute) { context in
                Text(footerText(now: context.date))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Picker("Sort By", selection: $viewModel.sortOrder) {
                    ForEach(AppSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Sort apps")
            .accessibilityLabel(Text("Sort apps"))
            .accessibilityIdentifier("sidebar.sortMenu")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.xxSmall)
        .padding(.bottom, 10)
    }

    private func footerText(now: Date) -> String {
        if viewModel.isLoading, viewModel.apps.isEmpty {
            return String(localized: "Syncing with App Store Connect…")
        }
        let count = String(localized: "\(viewModel.apps.count) apps")
        guard let synced = viewModel.lastSyncedAt else { return count }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: synced, relativeTo: now)
        return String(localized: "\(count) · synced \(relative)")
    }
}
