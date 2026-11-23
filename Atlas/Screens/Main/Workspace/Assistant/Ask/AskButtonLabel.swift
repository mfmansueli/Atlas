//
//  AskButtonLabel.swift
//  Atlas
//

import SwiftUI

/// An asking button's label: the suggestion sparkle in purple and the
/// title, or "Claude Code Is Working…" while the app's request runs.
struct AskButtonLabel: View {
    let title: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "sparkle")
                .foregroundStyle(Palette.ai)
        }
    }
}
