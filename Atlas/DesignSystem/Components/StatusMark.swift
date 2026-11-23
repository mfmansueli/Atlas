//
//  StatusMark.swift
//  Atlas
//

import SwiftUI

/// A small round mark: a check when something is there and fine, an
/// exclamation mark when something is missing.
struct StatusMark: View {
    let isOK: Bool
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: isOK ? "checkmark" : "exclamationmark")
            .font(.system(size: size * 0.52, weight: .bold))
            .foregroundStyle(isOK ? Palette.ok : Palette.warn)
            .frame(width: size, height: size)
            .background(isOK ? Palette.ok.opacity(0.16) : Palette.warnTint, in: Circle())
            .accessibilityLabel(Text(isOK ? "Ready" : "Missing"))
    }
}

#Preview {
    HStack {
        StatusMark(isOK: true)
        StatusMark(isOK: false)
    }
    .padding()
}
