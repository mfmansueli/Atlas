//
//  RowActionButton.swift
//  Atlas
//

import SwiftUI

/// The row action (README — Design system §4): an action repeated in a list
/// or inside a suggestion (Accept, Send Reply, Connect) is tinted blue, not
/// filled, so the card's or sheet's one primary button stays the only
/// filled one. Always 24 pt (`.regular`), whatever page it sits in.
extension View {
    func rowActionButton() -> some View {
        buttonStyle(.bordered)
            .tint(.accentColor)
            .controlSize(.regular)
    }
}
