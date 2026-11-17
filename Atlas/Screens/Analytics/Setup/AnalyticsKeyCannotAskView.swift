//
//  AnalyticsKeyCannotAskView.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The key isn't Admin: which role is needed and where to change it.
struct AnalyticsKeyCannotAskView: View {
    let keyID: String?
    let onTryAgain: () -> Void

    static let usersAndAccessURL = URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "key")
                .font(.system(size: 30))
                .foregroundStyle(Palette.warning)
                .accessibilityHidden(true)
            Text("Only an Admin key can ask Apple for reports")
                .font(.title2.weight(.semibold))
            Text(explanation)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
            AnalyticsSetupSteps(steps: [
                .init(
                    title: String(localized: "In App Store Connect, open Users and Access → Integrations"),
                    detail: String(localized: "App Store Connect API, Team Keys")
                ),
                .init(
                    title: String(localized: "Make a key with the Admin role"),
                    detail: String(localized: "Or ask your Account Holder or an Admin to make one")
                ),
                .init(
                    title: String(localized: "Add it to Atlas"),
                    detail: String(localized: "Settings → Account. Then come back here and ask again.")
                ),
            ])
            HStack(spacing: Spacing.small) {
                Button("Use Another Key…") { openSettings() }
                Button("Try Again", action: onTryAgain)
                Button("Open Users and Access") { NSWorkspace.shared.open(Self.usersAndAccessURL) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.setup.keyCannotAsk")
    }

    private var explanation: String {
        let key = keyID.map { String(localized: "Atlas uses key \($0), which isn’t an Admin key.") }
            ?? String(localized: "The key Atlas uses isn’t an Admin key.")
        let rule = String(localized: """
        Apple lets only Admin keys ask for analytics reports. Once they exist, keys with the Admin, Finance or Sales role can \
        read them.
        """)
        return key + " " + rule
    }
}

#Preview {
    AnalyticsKeyCannotAskView(keyID: "2X9R4HXF34", onTryAgain: {})
        .padding()
        .frame(width: 900, height: 560)
}
