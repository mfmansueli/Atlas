//
//  OverviewAfterReleaseCard.swift
//  Atlas
//

import SwiftUI

/// "After release": Analytics, Ratings & Reviews and Product Pages, one
/// line each with Open (README — redesign, November 22).
struct OverviewAfterReleaseCard: View {
    let rows: [OverviewAfterReleaseRow]
    let onOpen: (AppWorkspaceSection) -> Void

    var body: some View {
        OverviewListCard(title: String(localized: "After release"), titleIdentifier: "overview.afterRelease.title") {
            ForEach(rows) { row in
                OverviewListRow(section: row.section, title: row.title, detail: row.detail) {
                    if row.count > 0 {
                        if row.countsSuggestions {
                            SuggestionBadge(count: row.count)
                        } else {
                            NeutralCountPill(count: row.count)
                        }
                    }
                    Button("Open") { onOpen(row.section) }
                        .secondaryButton()
                        .fixedSize()
                        .accessibilityLabel(Text(row.accessibilityText))
                        .accessibilityIdentifier("overview.afterRelease.open.\(row.section.rawValue)")
                }
                .accessibilityIdentifier("overview.afterRelease.row.\(row.section.rawValue)")
            }
        }
        .accessibilityIdentifier("overview.afterRelease")
    }
}
