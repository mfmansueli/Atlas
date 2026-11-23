//
//  NeutralCountPill.swift
//  Atlas
//

import SwiftUI

/// A gray count: new findings to read. Purple stays for suggestions to accept.
struct NeutralCountPill: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Palette.label)
            .padding(.horizontal, 5)
            .frame(minWidth: 16, minHeight: 16)
            .background(Palette.fill3, in: Capsule())
            .accessibilityHidden(true)
    }
}
