//
//  SecondaryButton.swift
//  Atlas
//

import SwiftUI

/// The secondary button (README — Design system §4): a neutral capsule,
/// 28 pt, for everything that isn't the card's one main action (Review,
/// Choose Folder…, Cancel).
extension View {
    func secondaryButton() -> some View {
        buttonStyle(.bordered)
            .controlSize(.large)
    }
}
