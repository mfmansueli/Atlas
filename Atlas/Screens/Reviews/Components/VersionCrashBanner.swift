//
//  VersionCrashBanner.swift
//  Atlas
//

import SwiftUI

/// Above Reviews while the newest version crashes more, or its reviews
/// mention crashes (Redesign, 23 November): one amber banner, “**Version
/// 1.4 averages 3.9 ★ from 11 reviews; 1.3 averaged 4.7 ★.** 6 of the 11
/// mention a crash, and crashes are 3.2× higher on 1.4.”, with See
/// Stability when Analytics has the numbers and Pause Phased Release…
/// while a phased release rolls out. Pausing asks first, as on the
/// version card.
struct VersionCrashBanner: View {
    let summary: VersionReviewsSummary
    /// Analytics' report when it says the version crashes more.
    let stability: StabilityReport?
    /// The version's release; nil before it's read.
    let release: ReleaseViewModel?
    let onOpenStability: () -> Void

    var body: some View {
        Banner(kind: .warning, title: summary.lead, message: summary.detail(crashTimes: stability?.times), isInline: true) {
            if stability != nil {
                Button(String(localized: "See Stability", comment: "kind:button"), action: onOpenStability)
                    .accessibilityIdentifier("reviews.stability.open")
            }
            if let release, StabilityAlertText.canPause(release.phase) {
                Button("Pause Phased Release…") { release.request(.pause) }
                    .disabled(release.busyAction != nil)
                    .accessibilityIdentifier("reviews.stability.pause")
            }
        }
        // Inside the page's margins: the banner's own are for the top of a window.
        .padding(.horizontal, -Spacing.large)
        .padding(.vertical, -Spacing.small)
        .accessibilityIdentifier("reviews.stability")
        .confirmationDialog(
            release?.confirming?.confirmation(version: release?.versionString ?? "") ?? "",
            isPresented: Binding { release?.confirming != nil } set: { if !$0 { release?.confirming = nil } },
            titleVisibility: .visible,
            presenting: release?.confirming
        ) { action in
            Button(action.confirmTitle(version: release?.versionString ?? "")) {
                Task { await release?.perform(action) }
            }
            Button("Not Now", role: .cancel) {}
        } message: { action in
            Text(action.consequence(version: release?.versionString ?? ""))
        }
    }
}
