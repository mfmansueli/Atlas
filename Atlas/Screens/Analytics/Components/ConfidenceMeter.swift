//
//  ConfidenceMeter.swift
//  Atlas
//

import SwiftUI

/// How sure a rate is, as three rising bars: three filled when its range
/// is tight, one when it's rough. Decorative: the rate's tooltip and
/// VoiceOver value say the same in words.
struct ConfidenceMeter: View {
    /// 0…3 filled bars.
    let bars: Int

    private static let heights: [CGFloat] = [4, 6.5, 9]

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: Radius.flag)
                    .fill(index < bars ? Palette.label2 : Palette.separator2)
                    .frame(width: 2.5, height: Self.heights[index])
            }
        }
        .frame(height: 9, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ConfidenceMeter(bars: 1)
        ConfidenceMeter(bars: 2)
        ConfidenceMeter(bars: 3)
    }
    .padding()
}
