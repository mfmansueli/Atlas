//
//  SidebarFit.swift
//  Atlas
//

import CoreGraphics

/// How the sidebar fits its height (README-DS §11, board 71). The footer
/// never changes: Settings and Help ▾ side by side with their names, then
/// the version. Under 600 pt of sidebar the app card drops its "other
/// apps" line and the rows tighten to 27 pt; sections never disappear.
/// Only if they still don't fit do they scroll under the footer, which
/// then fades them out at its top edge.
struct SidebarFit: Equatable {
    /// The whole sidebar column.
    var sidebarHeight: CGFloat = 0
    /// "App" and the app card over the sections.
    var headerHeight: CGFloat = 0
    /// The first section's top, from its last report.
    var firstSectionTop: CGFloat?
    /// The last section's bottom; nil while it isn't drawn because it's
    /// out of sight.
    var lastSectionBottom: CGFloat?
    /// Settings, Help and the version.
    var footerHeight: CGFloat = 0

    /// The list's own margins above the first section and below the last.
    static let listMargins: CGFloat = 24

    /// The sidebar is shorter than 600 pt: no "other apps" line, 27 pt rows.
    /// The rule reads the sidebar's own height, not the window's.
    var isCompact: Bool {
        sidebarHeight > 0 && sidebarHeight < Metrics.sidebarCompactHeight
    }

    /// The height of a section's row.
    var rowHeight: CGFloat {
        isCompact ? Metrics.sidebarCompactRowHeight : Metrics.sidebarRowHeight
    }

    /// The sections from the first's top to the last's bottom, which
    /// doesn't change as the list scrolls.
    var sectionsSpan: CGFloat? {
        guard let firstSectionTop, let lastSectionBottom else { return nil }
        return max(0, lastSectionBottom - firstSectionTop)
    }

    /// The sections don't fit over the footer: they scroll under it, with
    /// the fade. Never before the sidebar, its footer and its first section
    /// are measured, nor without sections (no app chosen yet).
    var sectionsScrollUnder: Bool {
        guard sidebarHeight > 0, footerHeight > 0, firstSectionTop != nil else { return false }
        guard let span = sectionsSpan else { return true }
        return headerHeight + Self.listMargins + span + footerHeight > sidebarHeight
    }

    /// Keeps a section's position when it's the first or the last; true
    /// when it changed what's kept.
    mutating func report(section: AppWorkspaceSection, top: CGFloat, bottom: CGFloat) -> Bool {
        let old = self
        if section == AppWorkspaceSection.sidebarFirst { firstSectionTop = top.rounded() }
        if section == AppWorkspaceSection.sidebarLast { lastSectionBottom = bottom.rounded() }
        return self != old
    }
}
