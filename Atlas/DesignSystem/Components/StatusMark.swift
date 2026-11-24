//
//  StatusMark.swift
//  Atlas
//

import SwiftUI

/// A small status symbol (README-DS §13): done when something is there and
/// fine, needs you when something is missing. The system's filled symbol,
/// no circle drawn behind it.
struct StatusMark: View {
    let isOK: Bool
    var size: CGFloat = 20

    var body: some View {
        let status: StatusSymbol = isOK ? .done : .needsYou
        Image(systemName: status.symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(status.color)
            .frame(width: size * 0.8, height: size * 0.8)
            .frame(width: size, height: size)
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
