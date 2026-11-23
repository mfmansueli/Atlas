//
//  ProChip.swift
//  Atlas
//

import SwiftUI

/// The small PRO chip on a feature that's part of Pro, shown in Free
/// before it's clicked so the paywall is never a surprise.
struct ProChip: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(.footnote.weight(.bold))
            .kerning(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(height: 15)
            .background(PaywallStyle.gradient, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
            .accessibilityLabel(Text("Part of Pro"))
            .accessibilityIdentifier("pro.chip")
    }
}

#Preview {
    ProChip().padding()
}
