//
//  PlainButton.swift
//  Atlas
//

import SwiftUI

/// The plain button (README — Design system §4): blue text, no capsule,
/// for Show Me How, What to Try and links inside a sentence.
extension View {
    func plainButton() -> some View {
        buttonStyle(.link)
    }
}
