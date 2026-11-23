//
//  PageControlSize.swift
//  Atlas
//

import SwiftUI

extension View {
    /// The control size of a page or a sheet (README — Design system §4 and
    /// README — redesign, November 22): buttons, menus and segmented
    /// controls are 28 pt (`.large` on macOS 26), so a row of controls lines
    /// up. Rows, tables, suggestions and toasts step down to 24 pt
    /// (`.regular`, as `rowActionButton()` does). Text fields, switches and
    /// spinners keep the system's sizes. The toolbar has its own.
    func pageControlSize() -> some View {
        controlSize(.large)
    }
}
