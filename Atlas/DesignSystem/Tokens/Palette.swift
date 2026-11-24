//
//  Palette.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Every color the UI uses, by role (README — Design system §1). The values
/// live in the asset catalogue (`Assets.xcassets/Palette`), one Color Set per
/// token with Any, Dark and High Contrast variants; `AccentColor` is the
/// accent. Surfaces and separators are the system's. Swap values there,
/// never at the call site.
///
/// Two colours mean something: **blue** is what you do (`accent`), **purple**
/// is what AI brings (`ai…`). Green, amber and red (`ok`, `warn`, `err`) only
/// describe state. Section colours only tint their SF Symbols (§13).
enum Palette {
    // MARK: - Accent

    /// The primary button, selection, focus, switches, “changed, not pushed”.
    static let accent = Color.accentColor
    /// Links and plain buttons.
    static let accentText = Color(.accentText)
    static let accentTint = Color(.accentTint)

    // MARK: - Text

    static let label = Color.primary
    /// Secondary text, darker than the system's so 11 pt grey still passes 4.5:1.
    static let label2 = Color(.label2)
    /// Placeholders, disabled controls and separators only: 2.8:1 on white,
    /// never readable text. Readable text is `label2`.
    static let label3 = Color(.label3)

    // MARK: - Surfaces

    /// Behind the sidebar pane.
    static let window = Color(nsColor: .windowBackgroundColor)
    /// Tables and editors.
    static let content = Color(nsColor: .textBackgroundColor)
    /// Cards, popovers and sheets.
    static let raised = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    /// Control edges and stronger dividers.
    static let separator2 = Color(.separator2)
    /// Chips, tokens and flag tiles, from faint to strong.
    static let fill1 = Color(.fill1)
    static let fill2 = Color(.fill2)
    static let fill3 = Color(.fill3)
    /// Placeholder blocks while something loads.
    static let skeleton = Color(.skeleton)

    // MARK: - AI

    /// Text that came from an assistant or Atlas's checks and waits for you;
    /// the sparkles glyph.
    static let ai = Color(.ai)
    /// Marks drawn in the AI colour: diff highlights, dots, strokes.
    static let aiMark = Color(.aiMark)
    /// Suggestion cards and inline suggestions.
    static let aiSurface = Color(.aiSurface)
    /// Suggestion count badges, the Autopilot button when the assistant
    /// waits for you, AI motion. Never a section tile, never a filled action.
    static let aiFill = Color(.aiFill)
    /// The label on `aiFill`: white in light, dark in dark mode.
    static let aiFillLabel = Color(.aiFillLabel)
    /// An asking button while its request runs, and the token's halo.
    static let aiBusyTint = Color(.aiBusyTint)
    /// The edge of a suggestion and of an asking button while it runs.
    static let aiEdge = Color(.aiEdge)

    // MARK: - State

    /// Live, Accepted, Connected, a check that passes.
    static let ok = Color(.ok)
    /// Needs an answer; close to a limit.
    static let warn = Color(.warn)
    static let warnMark = Color(.warnMark)
    static let warnTint = Color(.warnTint)
    /// Errors, rejected, destructive button text. Never decoration.
    static let err = Color(.err)
    static let errMark = Color(.errMark)
    static let errTint = Color(.errTint)

    /// Price increase: text, mark (arrows, bars) and pill tint.
    static let increase = Color(.increase)
    static let increaseMark = Color(.increaseMark)
    static let increaseTint = Color(.increaseTint)
    /// Price decrease.
    static let decrease = Color(.decrease)
    static let decreaseMark = Color(.decreaseMark)
    static let decreaseTint = Color(.decreaseTint)

    /// The 8 pt dot on anything that isn't pushed yet.
    static let unsaved = Color(.unsaved)

    // MARK: - Sections

    /// Each section's system colour (README — Design system §13): its
    /// symbol in the sidebar, and the few marks drawn in it (stars,
    /// Analytics' funnel). Purple is never one of them: it means AI. The
    /// values are `SectionStyle`'s.
    static let sectionOverview = SectionStyle.overview.color
    static let sectionStorePage = SectionStyle.storePage.color
    static let sectionScreenshots = SectionStyle.screenshots.color
    static let sectionProductPages = SectionStyle.productPages.color
    static let sectionEvents = SectionStyle.inAppEvents.color
    static let sectionNominations = SectionStyle.nominations.color
    static let sectionAppInformation = SectionStyle.appInformation.color
    static let sectionPricing = SectionStyle.pricing.color
    static let sectionReviews = SectionStyle.reviews.color
    static let sectionAnalytics = SectionStyle.analytics.color

    // MARK: - Brand

    /// The hero button's tint: Welcome's Get Started, the paywall's buy.
    static let heroBlue = Color(.heroBlue)
    /// The brand gradient's ends: the icon, Welcome, About and Atlas Pro only.
    static let brandTop = Color(.brandTop)
    static let brandBottom = Color(.brandBottom)
    /// The brand gradient, top to bottom.
    static let brand = LinearGradient(colors: [brandTop, brandBottom], startPoint: .top, endPoint: .bottom)

    // MARK: - Viewers

    /// The full-size viewers' stage and panels: near-black in every appearance.
    static let viewerStage = Color(.viewerStage)
    static let viewerPanel = Color(.viewerPanel)

    // MARK: - Aliases

    /// Fill behind app-icon placeholders and empty tiles.
    static let tile = fill2
    /// Dashed outline of drop zones.
    static let dropOutline = separator2
    /// The neutral stage screenshot renders sit on (viewer, template
    /// canvas), so their own colors read true.
    static let stage = Color(.stage)
}
