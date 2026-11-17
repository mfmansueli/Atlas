//
//  TemplateColor+SwiftUI.swift
//  Atlas
//

import SwiftUI

extension TemplateColor {
    /// The color in sRGB, as the renderer draws it.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
