//
//  PrimaryButton.swift
//  Atlas
//

import SwiftUI

/// The primary button (README — Design system §4): filled blue, white label,
/// 28 pt. One per card or sheet, its main action (Submit for Review…,
/// Accept All Languages, Connect). In a sheet it is also Return.
extension View {
    func primaryButton(isDefault: Bool = false) -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(isDefault ? .defaultAction : nil)
    }
}
