//
//  ConnectFieldLabel.swift
//  Atlas
//

import SwiftUI

/// A connect field's name, where to find the value on App Store Connect's
/// page (when the window is wide enough) and a green check once the value
/// looks right (README-Welcome).
struct ConnectFieldLabel: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    var showsHint = true
    let looksRight: Bool
    let identifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            Text(title)
                .atlasTextStyle(.headline)
                .layoutPriority(1)
            if showsHint {
                Text(hint)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(identifier).hint")
            }
            if looksRight {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.ok)
                    .accessibilityLabel(Text("Looks right"))
                    .accessibilityIdentifier("\(identifier).looksRight")
            }
            if !showsHint {
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ConnectFieldLabel(title: "Issuer ID", hint: "top of the page", looksRight: true, identifier: "a")
        ConnectFieldLabel(title: "Key ID", hint: "next to your key", showsHint: false, looksRight: false, identifier: "b")
    }
    .padding()
    .frame(width: 360)
}
