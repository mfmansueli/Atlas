//
//  ConnectHeader.swift
//  Atlas
//

import SwiftUI

/// The top of the connect form: the app's tile, the title and one line on
/// what the key is for.
struct ConnectHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.small) {
            RoundedRectangle(cornerRadius: Radius.popover, style: .continuous)
                .fill(Palette.brand)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "globe")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 3)
                .padding(.bottom, Spacing.xSmall)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Atlas uses an App Store Connect API key to read your apps and push prices and store text.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }
}

#Preview {
    ConnectHeader(title: "Connect to App Store Connect")
        .padding()
}
