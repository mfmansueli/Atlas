//
//  MenuBarProgressBar.swift
//  Atlas
//

import SwiftUI

/// The menu's thin bar: 5 points, the accent colour on a light track.
struct MenuBarProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(Palette.fill3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

#Preview {
    MenuBarProgressBar(fraction: 0.4)
        .frame(width: 300)
        .padding()
}
