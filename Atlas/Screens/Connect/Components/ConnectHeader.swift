//
//  ConnectHeader.swift
//  Atlas
//

import SwiftUI

/// The top of the connect form: the app's tile, the title and one line on
/// what the key is for. Adding another team's key, a small line over the
/// title says so and the line under it names the team that stays.
struct ConnectHeader: View {
    let title: LocalizedStringKey
    var eyebrow: String?
    var subtitle: String?

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
            if let eyebrow {
                Text(eyebrow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("connect.eyebrow")
            }
            Text(title)
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            subtitleText
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .accessibilityIdentifier("connect.subtitle")
        }
    }

    private var subtitleText: Text {
        if let subtitle { return Text(subtitle) }
        return Text("Atlas uses an App Store Connect API key to read your apps and push prices and store text.")
    }
}

#Preview {
    ConnectHeader(title: "Connect to App Store Connect")
        .padding()
}
