//
//  AIStartLabel.swift
//  Atlas
//

import SwiftUI

/// The label of a button that starts AI work from inside a page (Make the
/// Artwork…, an empty slot's Ask…): the sparkles glyph and a purple title on
/// a secondary (`.bordered`) button, the look of the Autopilot button at
/// rest. README — Design system §4: such a button is never filled; a purple
/// fill means only "the assistant is waiting for you".
struct AIStartLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "sparkles")
        }
        .foregroundStyle(Palette.ai)
    }
}

#Preview {
    Button {} label: { AIStartLabel("Make the Artwork…") }
        .buttonStyle(.bordered)
        .padding()
}
