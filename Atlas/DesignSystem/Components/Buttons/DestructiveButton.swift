//
//  DestructiveButton.swift
//  Atlas
//

import SwiftUI

/// The destructive button (README — Design system §4): a secondary button
/// with a red label (Delete…, Disconnect…, Remove…), confirmed in place.
/// Give the `Button` `role: .destructive` so VoiceOver says so too. Never
/// filled red. Its size comes from where it sits: 28 pt in a page or a
/// sheet, 24 pt in a row.
extension View {
    func destructiveButton() -> some View {
        buttonStyle(.bordered)
            .foregroundStyle(Palette.err)
    }
}
