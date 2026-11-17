//
//  MiniFunnel.swift
//  Atlas
//

import SwiftUI

/// The narrowing bars above the setup text: a funnel in five lines.
struct MiniFunnel: View {
    private static let widths: [CGFloat] = [1, 0.78, 0.58, 0.4, 0.26]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Self.widths, id: \.self) { width in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.sectionAnalytics.opacity(0.25 + width * 0.6))
                    .frame(width: 120 * width, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}
