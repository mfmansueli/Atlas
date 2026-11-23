//
//  WelcomeChipView.swift
//  Atlas
//

import SwiftUI

/// A chip as the header draws it: white on the icon's blue, a flag and
/// the language's own name, or a white coin with the currency and a price.
struct WelcomeChipView: View {
    let chip: WelcomeChip

    static let coinColor = Palette.brandBottom

    var body: some View {
        HStack(spacing: 6) {
            switch chip.content {
            case let .language(flag, name):
                Text(flag)
                    .font(.system(size: 16))
                Text(verbatim: name)
            case let .price(currency, amount):
                Text(verbatim: currency)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Self.coinColor)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(.white, in: Capsule())
                    .padding(.leading, -3)
                Text(verbatim: amount)
                    .monospacedDigit()
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize()
        .padding(.leading, 8)
        .padding(.trailing, 11)
        .frame(height: 30)
        .background(.white.opacity(0.2), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
    }
}

#Preview {
    HStack {
        WelcomeChipView(chip: WelcomeChip(content: .language(flag: "🇩🇪", name: "Deutsch"), delay: 0))
        WelcomeChipView(chip: WelcomeChip(content: .price(currency: "R$", amount: "24,90"), delay: 0))
    }
    .padding()
    .background(Palette.brand)
}
