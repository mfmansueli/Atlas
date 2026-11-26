//
//  Metrics+PageCardStrip.swift
//  Atlas
//

import CoreGraphics

/// The page card strip's sizes (board 88, README-DS §16; design-tokens.json
/// → pageCardStrip): the prototype's `.inI-c` and `.inI-go`.
extension Metrics {
    static let pageCardHeight: CGFloat = 46
    static let pageCardMinWidth: CGFloat = 150
    /// The card's symbol tile.
    static let pageCardTile: CGFloat = 26
    /// Where the strip fades out on the right.
    static let pageCardFade: CGFloat = 44
    /// The round button over the fade that scrolls on.
    static let pageCardScrollButton: CGFloat = 24
}
