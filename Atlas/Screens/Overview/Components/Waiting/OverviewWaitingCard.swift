//
//  OverviewWaitingCard.swift
//  Atlas
//

import SwiftUI

/// "65 suggestions to review": one row per section with where its
/// suggestions are, the purple count or Reviewed, and Review (or Open).
struct OverviewWaitingCard: View {
    let rows: [OverviewWaitingSection]
    let onOpen: (AppWorkspaceSection) -> Void

    private var total: Int { rows.reduce(0) { $0 + $1.count } }

    var body: some View {
        OverviewListCard(title: OverviewWaitingSection.title(total: total), titleIdentifier: "overview.waiting.title") {
            ForEach(rows) { row in
                OverviewListRow(section: row.section, title: row.title, detail: row.detail) {
                    if row.count > 0 {
                        SuggestionBadge(count: row.count)
                    } else {
                        Pill(text: String(localized: "✓ Reviewed"), style: .outline)
                            .fixedSize()
                    }
                    Button(row.buttonTitle) { onOpen(row.section) }
                        .secondaryButton()
                        .fixedSize()
                        .accessibilityLabel(Text(row.accessibilityText))
                        .accessibilityIdentifier("overview.waiting.open.\(row.section.rawValue)")
                }
                .accessibilityIdentifier("overview.waiting.row.\(row.section.rawValue)")
            }
        }
        .accessibilityIdentifier("overview.waiting")
    }
}
