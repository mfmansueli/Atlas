//
//  HelpPictureSource.swift
//  Atlas
//

import Foundation

/// Where a Help article's picture (`![caption](name)`) comes from: one of
/// Atlas's own drawings, or an image of that name bundled with the
/// articles. A drawing's name is drawn; any other name is looked up as an
/// image, so a screenshot can still be added later under a new name.
enum HelpPictureSource: Hashable, Sendable {
    case drawing(HelpDrawing)
    case asset(String)

    init(name: String) {
        if let drawing = HelpDrawing(rawValue: name) {
            self = .drawing(drawing)
        } else {
            self = .asset(name)
        }
    }
}
