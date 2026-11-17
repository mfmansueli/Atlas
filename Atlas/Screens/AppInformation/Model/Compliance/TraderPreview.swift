//
//  TraderPreview.swift
//  Atlas
//

import Foundation

/// What the preview's "In the EU" block shows beside App Compliance.
enum TraderPreview: Hashable, Sendable {
    /// The app isn't sold in the EU: no block.
    case hidden
    /// The trader's details on the page; highlighted while they're only
    /// suggested.
    case details(String, isSuggested: Bool)
    case nonTrader
    /// Apple has a declaration the API doesn't show.
    case declaredAtApple
}
