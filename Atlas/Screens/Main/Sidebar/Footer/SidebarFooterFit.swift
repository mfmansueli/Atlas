//
//  SidebarFooterFit.swift
//  Atlas
//

import CoreGraphics

/// How the sidebar's footer fits under the sections. When the window is
/// tall enough, Settings, Show the Tour and Atlas Help are rows; when the
/// sections and those rows don't both fit, the three fold into one row of
/// icons; when even that doesn't fit, the sections scroll under the
/// footer, which then has a solid background and a line on its top edge,
/// so a section never shows through it.
struct SidebarFooterFit: Equatable {
    /// The whole sidebar column.
    var sidebarHeight: CGFloat = 0
    /// "App" and the app menu over the sections.
    var headerHeight: CGFloat = 0
    /// The first section's top, from its last report.
    var firstSectionTop: CGFloat?
    /// The last section's bottom; nil while it isn't drawn because it's
    /// out of sight.
    var lastSectionBottom: CGFloat?
    /// The footer with its three rows, from when it last showed them.
    var fullFooterHeight: CGFloat = 0
    /// The footer with its row of icons, from when it last showed it.
    var compactFooterHeight: CGFloat?

    /// The list's own margins above the first section and below the last.
    static let listMargins: CGFloat = 24
    /// What folding saves: two of the three 32 pt rows and their spacing.
    static let foldSaving: CGFloat = 2 * (32 + 2)

    /// The sections from the first's top to the last's bottom, which
    /// doesn't change as the list scrolls.
    var sectionsSpan: CGFloat? {
        guard let firstSectionTop, let lastSectionBottom else { return nil }
        return max(0, lastSectionBottom - firstSectionTop)
    }

    /// Nothing folds before the sidebar, its footer and its first section
    /// are measured, nor when it shows no sections (no app chosen yet).
    private var isMeasured: Bool {
        sidebarHeight > 0 && fullFooterHeight > 0 && firstSectionTop != nil
    }

    /// Settings, Show the Tour and Atlas Help fold into a row of icons.
    var isCompact: Bool {
        guard isMeasured else { return false }
        guard let span = sectionsSpan else { return true }
        return needed(span: span, footer: fullFooterHeight) > sidebarHeight
    }

    /// The sections scroll under the folded footer.
    var sectionsScrollUnder: Bool {
        guard isCompact else { return false }
        guard let span = sectionsSpan else { return true }
        let footer = compactFooterHeight ?? fullFooterHeight - Self.foldSaving
        return needed(span: span, footer: footer) > sidebarHeight
    }

    private func needed(span: CGFloat, footer: CGFloat) -> CGFloat {
        headerHeight + Self.listMargins + span + footer
    }

    /// Keeps the footer's height for the way it shows now. Folded, the rows'
    /// height stays the one last seen, moved by as much as the folded
    /// footer changed (the version's status came or went), so it never
    /// guesses a smaller one and flips back and forth.
    mutating func footerMeasured(_ height: CGFloat) {
        guard isCompact else {
            fullFooterHeight = height
            compactFooterHeight = nil
            return
        }
        if let old = compactFooterHeight {
            fullFooterHeight += height - old
        } else {
            fullFooterHeight = max(fullFooterHeight, height + Self.foldSaving)
        }
        compactFooterHeight = height
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
