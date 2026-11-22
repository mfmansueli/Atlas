//
//  WelcomePoint.swift
//  Atlas
//

import SwiftUI

/// One of the three points under "Welcome to Atlas": a small tile in the
/// icon's blue, a title and, when there's room, a line under it.
struct WelcomePoint: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var showsDetail = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: WelcomeHeader.gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if showsDetail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomePoint(
        systemImage: "globe",
        title: "Every storefront, one place",
        detail: "Your page in 175 countries and regions and every language, without opening App Store Connect."
    )
    .frame(width: 280)
    .padding()
}
