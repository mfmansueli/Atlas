//
//  SidebarFooter.swift
//  Atlas
//

import SwiftUI

/// The bottom of the sidebar (README-DS §11, board 71): two rows, the same
/// at every height. Settings and Help ▾ side by side, always with their
/// names, then the version's card. It sits on the sidebar's glass and never
/// scrolls; when the sections scroll under it, it fades them out at its
/// top edge.
struct SidebarFooter: View {
    /// The selected app's version; nil hides its card.
    let version: VersionStatusSummary?
    /// An app shows: Show the Tour has its tips' places.
    let showsTour: Bool
    /// Shorter than 600 pt: the version's card tightens.
    var isCompact = false
    /// The sections scroll under the footer.
    var sectionsScrollUnder = false
    let onSettings: () -> Void
    let onHelp: () -> Void
    let onTour: () -> Void
    let onShortcuts: () -> Void
    let onVersion: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                Button(action: onSettings) {
                    SidebarFooterTile(title: String(localized: "Settings", comment: "kind:section-title"), systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .help(String(localized: "Settings  ⌘,", comment: "kind:tooltip"))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(localized: "Settings", comment: "kind:section-title")))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("sidebar.settings")
                // The tour's last tip.
                .tourTip(.settings, arrowEdge: .trailing)
                SidebarHelpMenu(showsTour: showsTour, onHelp: onHelp, onTour: onTour, onShortcuts: onShortcuts)
                    .accessibilityIdentifier("sidebar.help")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(String(localized: "Settings and Help", comment: "kind:accessibility-label")))
            if let version {
                VersionStatusFooter(summary: version, isCompact: isCompact, action: onVersion)
            }
        }
        .padding(.horizontal, Spacing.small)
        .padding(.top, Spacing.xxSmall)
        .padding(.bottom, Spacing.small)
        .background(alignment: .top) {
            if sectionsScrollUnder { fade }
        }
    }

    /// The sidebar's own material behind the footer, coming in over 14 pt
    /// above it, so the sections fade out as they pass under it.
    private var fade: some View {
        SidebarMaterialBackground()
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: Metrics.sidebarFadeHeight)
                    Rectangle()
                }
            }
            .padding(.top, -Metrics.sidebarFadeHeight)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    SidebarFooter(
        version: VersionStatusSummary(versionString: "1.4", phase: .prepare), showsTour: true,
        onSettings: {}, onHelp: {}, onTour: {}, onShortcuts: {}, onVersion: {}
    )
    .frame(width: 240)
}
