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
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.warn)
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
                    detail: String(localized: "Or ask your Account Holder or an Admin")
                ),
                .init(
                    title: String(localized: "Add it to Atlas"),
                    detail: String(localized: "Add it in Settings → Accounts, then ask again.")
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
        let key = keyID.map { String(localized: "Key \($0) isn’t an Admin key.") }
            ?? String(localized: "This key isn’t an Admin key.")
        let rule = String(localized: """
        Only Admin keys can ask for reports; Admin, Finance and Sales keys can read them.
        """)
        return key + " " + rule
    }
}

#Preview {
    AnalyticsKeyCannotAskView(keyID: "2X9R4HXF34", onTryAgain: {})
        .padding()
        .frame(width: 900, height: 560)
}
