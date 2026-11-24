//
//  AutopilotDirection.swift
//  Atlas
//

import Foundation

/// One design direction for the set: an Atlas template from the
/// design AI, or one of Atlas's starters.
struct AutopilotDirection: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// "Quiet Indigo".
    var name: String
    /// "Your indigo, with a New York headline over the device."
    var rationale: String
    /// Where it came from; `.none` for Atlas's starters.
    var source: DesignProjectKind
    /// The assistant that sent it; nil for a starter.
    var client: String?
    var template: ScreenshotTemplate
    /// The header and search artwork's look, when the design AI sent one of
    /// its own (`extrasTemplates.artwork`); nil uses `template`'s.
    var artworkTemplate: ScreenshotTemplate?
    /// The header and search artwork as Claude made them, one page
    /// per canvas; nil draws them with Atlas's own layout in
    /// `artworkLook`.
    var artworkDesign: AutopilotArtworkDesign?
    /// The App Preview's captions and end card look, when sent
    /// (`extrasTemplates.appPreview`); nil uses `template`'s.
    var previewTemplate: ScreenshotTemplate?
    /// Where to refine it, e.g. the Claude Design project's link.
    var link: String?
    /// Changed after "Ask for changes".
    var isRevised = false
    /// Language checks with the captions: too long, mirrors, fits.
    var checks: [AutopilotDirectionCheck] = []
    var receivedAt: Date
    /// The design AI's details and how sure, beside the rationale; nil for
    /// a starter, when none came and in runs saved before.
    var layers: SuggestionLayers?

    /// The artwork's look: its own, else the screenshots'.
    var artworkLook: ScreenshotTemplate { artworkTemplate ?? template }

    /// The App Preview's look: its own, else the screenshots'.
    var previewLook: ScreenshotTemplate { previewTemplate ?? template }

    /// The badge's label: "Claude" or "Starter".
    var sourceTitle: String {
        source == .none ? String(localized: "Starter") : DesignProjectKind.claude
    }
}
