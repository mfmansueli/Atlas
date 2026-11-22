//
//  Radius.swift
//  Atlas
//

import CoreGraphics

/// The seven corner radii (README — Design system §6), plus capsules for
/// buttons, pills, badges and segmented controls. Always `.continuous`.
enum Radius {
    /// Tags and flag tiles.
    static let flag: CGFloat = 4
    static let badge: CGFloat = 4
    /// Menu rows and small tiles.
    static let menuRow: CGFloat = 6
    /// Text fields, keyword tokens and sidebar rows.
    static let field: CGFloat = 8
    /// Banners and suggestions.
    static let banner: CGFloat = 10
    static let card: CGFloat = 12
    /// Popovers and tips.
    static let popover: CGFloat = 16
    static let sheet: CGFloat = 20
}
