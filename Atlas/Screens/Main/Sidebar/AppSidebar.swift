//
//  AppSidebar.swift
//  Atlas
//

import SwiftUI

/// The sidebar: "App" over the app being viewed (opening the app menu) at
/// the top, its sections grouped by what the person is doing, each with
/// its count, then Settings and Show the Tour (board 63) over the
/// version's status at the bottom. Also the library's loading, empty and
/// error states.
struct AppSidebar: View {
    @Bindable var viewModel: AppListViewModel
    let summaries: AppSummaryStore
    let accounts: [TeamAccount]
    let currentAccountID: TeamAccount.ID?
    /// The selected app's counts, per section.
    let counts: SectionBadgeCounts
    /// The selected app's version, for the footer; nil hides it.
    let version: VersionStatusSummary?
    var onSelectAccount: (TeamAccount) -> Void = { _ in }
    var onAddKey: () -> Void = {}
    /// The footer was clicked.
    var onVersion: () -> Void = {}

    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(ChangeQueue.self) private var changes
    @Environment(PricingModeStore.self) private var pricingModes
    @Environment(FieldSuggestionStore.self) private var suggestions
    /// Nil in previews.
    @Environment(FirstRunTour.self) private var tour: FirstRunTour?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        List(selection: selection) {
            if viewModel.selectedApp != nil {
                ForEach(AppWorkspaceSectionGroup.allCases) { group in
                    Section {
                        ForEach(group.sections) { section in
                            SidebarSectionRow(
                                section: section, counts: counts, isSelected: navigator.section == section, appID: viewModel.selectedAppID
                            )
                            .tag(section)
                            .accessibilityIdentifier("sidebar.section.\(section.rawValue)")
                            // The tour's second tip: what a section and its number are.
                            .tourTip(section == .storePage ? .sections : nil, arrowEdge: .trailing)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar.sections")
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("App")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .padding(.horizontal, Spacing.small)
                    .accessibilityAddTraits(.isHeader)
                AppSwitcher(
                    viewModel: viewModel, accounts: accounts, currentAccountID: currentAccountID, indicators: indicators,
                    onSelectAccount: onSelectAccount, onAddKey: onAddKey, startsOpen: Self.opensAppMenu
                )
            }
            .padding(.horizontal, Spacing.small)
            .padding(.bottom, Spacing.xSmall)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.tiny) {
                SidebarUtilityRow(title: String(localized: "Settings"), systemImage: "gearshape", shortcut: "⌘,") {
                    openSettings()
                }
                .accessibilityIdentifier("sidebar.settings")
                // The tour's last tip.
                .tourTip(.settings, arrowEdge: .trailing)
                if viewModel.selectedApp != nil {
                    SidebarUtilityRow(title: String(localized: "Show the Tour"), systemImage: "questionmark", action: showTour)
                        .accessibilityIdentifier("sidebar.showTour")
                }
                if let version, viewModel.selectedApp != nil {
                    VersionStatusFooter(summary: version, action: onVersion)
                        .padding(.top, Spacing.xxSmall)
                }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.top, Spacing.xxSmall)
            .padding(.bottom, Spacing.small)
        }
        .overlay { state }
    }

    /// Show the Tour: the tips start again from the first, on Overview.
    private func showTour() {
        navigator.section = .overview
        // After the click that started it, so the first tip isn't closed
        // as if by a click elsewhere.
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            tour?.start()
        }
    }

    /// A DEBUG scene that opens with the app menu showing.
    static var opensAppMenu: Bool {
        #if DEBUG
        NavigationDebugLaunch.opensAppMenu
        #else
        false
        #endif
    }

    private var selection: Binding<AppWorkspaceSection?> {
        Binding {
            navigator.section
        } set: { section in
            if let section, section != navigator.section { navigator.section = section }
        }
    }

    /// What the app menu shows beside an app: unpushed changes and the
    /// suggestions to review.
    private func indicators(_ app: StoreApp) -> AppIndicators {
        let mode = pricingModes.mode(for: app.id)
        let pricing = summaries.pricing[app.id]?.value
        let appCounts = app.id == viewModel.selectedAppID ? counts : SectionBadgeCounts(
            appID: app.id,
            suggestions: suggestions,
            screenshots: ScreenshotsDocumentCenter.shared,
            pricing: SectionBadgeCounts.pricingCount(appID: app.id, summaries: summaries, modes: pricingModes, changes: changes),
            extras: SectionBadgeCounts.Extras(releaseProposals: ReleaseProposalStore.shared.pending(for: app.id).count)
        )
        return AppIndicators(
            pendingChangeCount: changes.count(for: app.id),
            suggestionCount: appCounts.total,
            localeCount: summaries.storePage[app.id]?.value?.localeCount,
            priceSuggestionCount: mode.showsSuggestions && pricing?.sellsAnything == true ? pricing?.heldBackTerritoryCount : nil
        )
    }

    @ViewBuilder
    private var state: some View {
        if viewModel.isLoading, viewModel.apps.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBlock(height: 22, cornerRadius: Radius.menuRow)
                }
                // The app menu's footer says it too, but nothing opens it yet.
                Text("Syncing with App Store Connect…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .padding(.top, Spacing.xSmall)
            }
            .padding(.horizontal, Spacing.medium)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 70)
            .accessibilityIdentifier("sidebar.loading")
        } else if let message = viewModel.errorMessage, viewModel.apps.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load apps", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .accessibilityIdentifier("sidebar.errorMessage")
            } actions: {
                Button("Try Again") { Task { await viewModel.load() } }
                    .accessibilityIdentifier("sidebar.retryButton")
            }
        } else if viewModel.hasLoaded, !viewModel.isLoading, viewModel.apps.isEmpty {
            ContentUnavailableView(
                "No apps",
                systemImage: "square.dashed",
                description: Text("This team doesn't have any apps in App Store Connect yet.")
            )
        }
    }
}
