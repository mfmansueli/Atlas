//
//  SidebarSectionRow.swift
//  Atlas
//

import SwiftUI

/// One section in the sidebar or the section menu: its tile, its name and
/// its count, and Autopilot's mark when it waits for the person there.
struct SidebarSectionRow: View {
    let section: AppWorkspaceSection
    let counts: SectionBadgeCounts
    var isSelected = false

    var body: some View {
        HStack(spacing: 9) {
            SectionIconTile(section: section)
            Text(section.title)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if counts.needsYou.contains(section) {
                AutopilotNeedsYouMark()
            }
            SectionCountBadge(count: counts.count(for: section), isNeutral: counts.isNeutral(section))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(counts.accessibilityText(for: section)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(section.fullTitle)  ⌘\(String(section.shortcutDigit))")
    }
}
