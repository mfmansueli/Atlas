//
//  PreviewRailCaption.swift
//  Atlas
//

import Foundation

/// The line under the App Store preview's row (README-Redesign, “On the
/// App Store preview”): what the row holds, with the real counts, and
/// "scroll for more" only while some of it is out of view.
enum PreviewRailCaption {
    /// "App Preview and 5 screenshots · scroll for more"; nil when the row
    /// holds nothing.
    static func text(appPreviews: Int, screenshots: Int, overflows: Bool) -> String? {
        guard let counts = counts(appPreviews: appPreviews, screenshots: screenshots) else { return nil }
        guard overflows else { return counts }
        return String(localized: "\(counts) · scroll for more", comment: "kind:label The row of App Previews and screenshots goes on past the edge")
    }

    /// "App Preview and 5 screenshots", "1 screenshot", "2 App Previews";
    /// nil for none of either.
    static func counts(appPreviews: Int, screenshots: Int) -> String? {
        switch (appPreviews, screenshots) {
        case (...0, ...0): nil
        case (...0, 1): String(localized: "1 screenshot")
        case (...0, _): String(localized: "\(screenshots) screenshots")
        case (1, ...0): String(localized: "App Preview", comment: "kind:label")
        case (1, 1): String(localized: "App Preview and 1 screenshot", comment: "kind:label")
        case (1, _): String(localized: "App Preview and \(screenshots) screenshots", comment: "kind:label")
        case (_, ...0): String(localized: "\(appPreviews) App Previews", comment: "kind:label")
        case (_, 1): String(localized: "\(appPreviews) App Previews and 1 screenshot", comment: "kind:label")
        default: String(localized: "\(appPreviews) App Previews and \(screenshots) screenshots", comment: "kind:label")
        }
    }
}
