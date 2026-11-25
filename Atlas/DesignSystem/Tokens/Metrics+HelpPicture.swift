//
//  Metrics+HelpPicture.swift
//  Atlas
//

import CoreGraphics

/// The sizes of Help's drawings of App Store Connect (README-Welcome's
/// "Get your App Store Connect key", the prototype's Help window in scene
/// connect-how), at the width they're drawn at before scaling.
extension Metrics {
    /// The page's width as drawn, then scaled to the article's column up to
    /// the largest width: about 1.1 to 1.2 times, so the page's 10 pt type
    /// never draws smaller.
    static let helpPictureWidth: CGFloat = 400
    static let helpPictureMaxWidth: CGFloat = 480
    /// The ring around what to click, its halo, and the gap a filled
    /// button keeps inside it.
    static let helpRingWidth: CGFloat = 2
    static let helpRingHaloWidth: CGFloat = 3
    static let helpRingGap: CGFloat = 2
    /// The browser's three dots.
    static let helpPictureDot: CGFloat = 7
    /// The grey lines standing for a page's content, and their widths.
    static let helpPictureLine: CGFloat = 6
    static let helpPictureLongLine: CGFloat = 226
    static let helpPictureShortLine: CGFloat = 150
    /// Integrations' side list, the Generate API Key form and its + button.
    static let helpPictureSideWidth: CGFloat = 128
    static let helpPictureFormWidth: CGFloat = 200
    static let helpPictureAddButton: CGFloat = 18
    /// The selected tab's underline.
    static let helpPictureTabUnderline: CGFloat = 1.5
    /// The Team Keys table's Name, Key ID and Access columns.
    static let helpPictureNameColumn: CGFloat = 90
    static let helpPictureKeyIDColumn: CGFloat = 110
    static let helpPictureAccessColumn: CGFloat = 72
}
