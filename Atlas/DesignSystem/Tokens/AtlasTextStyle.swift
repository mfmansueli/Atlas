//
//  AtlasTextStyle.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The ten text styles (README — Design system §3) as tokens, with the
/// sizes `design-tokens.json` holds: nine are macOS's own styles, so they
/// follow the system's sizes and accessibility settings; Display is
/// Welcome's title. Views write them as the system's fonts or with
/// `.atlasTextStyle(_:)`.
enum AtlasTextStyle: String, CaseIterable, Sendable {
    case display
    case largeTitle
    case title1
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote

    /// Points, at the default text size.
    var size: CGFloat {
        switch self {
        case .display: 32
        case .largeTitle: 26
        case .title1: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote: 10
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .display: 38
        case .largeTitle: 32
        case .title1: 28
        case .title2: 22
        case .title3: 20
        case .headline: 16
        case .body: 18
        case .callout: 16
        case .subheadline: 14
        case .footnote: 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .largeTitle: .bold
        case .title1, .title2, .title3, .headline: .semibold
        case .body, .callout, .subheadline, .footnote: .regular
        }
    }

    /// The weight's name, as `design-tokens.json` writes it.
    var weightName: String {
        switch self {
        case .display, .largeTitle: "bold"
        case .title1, .title2, .title3, .headline: "semibold"
        case .body, .callout, .subheadline, .footnote: "regular"
        }
    }

    /// The font, written as the system's.
    var font: Font {
        switch self {
        case .display: .display
        case .largeTitle: .largeTitle.bold()
        case .title1: .title.weight(.semibold)
        case .title2: .title2.weight(.semibold)
        case .title3: .title3.weight(.semibold)
        case .headline: .body.weight(.semibold)
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        }
    }

    /// The macOS text style it follows; nil for Display, which is fixed.
    var systemStyle: NSFont.TextStyle? {
        switch self {
        case .display: nil
        case .largeTitle: .largeTitle
        case .title1: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        }
    }

    /// The name the catalog shows.
    var title: String {
        switch self {
        case .display: "Display"
        case .largeTitle: "Large Title"
        case .title1: "Title 1"
        case .title2: "Title 2"
        case .title3: "Title 3"
        case .headline: "Headline"
        case .body: "Body"
        case .callout: "Callout"
        case .subheadline: "Subheadline"
        case .footnote: "Footnote"
        }
    }
}

extension View {
    /// One of the ten text styles; see `AtlasTextStyle`.
    func atlasTextStyle(_ style: AtlasTextStyle) -> some View {
        font(style.font)
    }
}
