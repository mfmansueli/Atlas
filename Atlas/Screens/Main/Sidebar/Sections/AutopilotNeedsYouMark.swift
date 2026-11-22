//
//  AutopilotNeedsYouMark.swift
//  Atlas
//

import SwiftUI

/// The sidebar's mark on a section where Autopilot waits for the person
/// (“Autopilot needs you · Your turn”): the toolbar's solid purple, with
/// its sparkle, as tall as the counts beside it.
struct AutopilotNeedsYouMark: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Palette.suggestionBadgeText)
            .frame(width: 17, height: 17)
            .background(Palette.suggestionBadge, in: Circle())
            .help("Autopilot needs you")
            .accessibilityIdentifier("sidebar.autopilotNeedsYou")
    }
}

#Preview {
    SidebarSectionRow(section: .screenshots, counts: SectionBadgeCounts([.screenshots: 3], needsYou: [.screenshots]))
        .padding()
        .frame(width: 260)
}
