//
//  SidebarSectionRow.swift
//  Atlas
//

import SwiftUI

/// One section in the sidebar or the section menu: its tile, its name and
/// its count, and Autopilot's mark when it waits for the person there. A
/// purple count that goes up because suggestions came ticks (effect 4).
struct SidebarSectionRow: View {
    let section: AppWorkspaceSection
    let counts: SectionBadgeCounts
    var isSelected = false
    /// The app the counts are of: another app's counts never tick.
    var appID: StoreApp.ID?

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
            // On the badge's own view, which stays at zero, so the first
            // suggestion ticks too; gray counts are findings, not suggestions.
            SectionCountBadge(count: counts.count(for: section), isNeutral: counts.isNeutral(section))
                .modifier(CountTick(count: counts.isNeutral(section) ? 0 : counts.count(for: section), scope: appID))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(counts.accessibilityText(for: section)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(section.fullTitle)  ⌘\(String(section.shortcutDigit))")
    }
}
