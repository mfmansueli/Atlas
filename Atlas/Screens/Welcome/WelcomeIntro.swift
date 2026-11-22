//
//  WelcomeIntro.swift
//  Atlas
//

import SwiftUI

/// The words under the welcome header: what Atlas is, three points, Get
/// Started, and the one thing people worry about (the API key stays in
/// this Mac's Keychain).
struct WelcomeIntro: View {
    let layout: WelcomeLayout
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: layout.isShort ? 10 : 14) {
            Text("Welcome to Atlas")
                .font(.system(size: layout.isShort ? 24 : 30, weight: .bold))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.title")
            Text("""
            Atlas keeps your App Store page right in every country: the words, the screenshots and the prices. \
            It suggests what to change, you review it, and one push sends it to App Store Connect.
            """)
            .font(.system(size: layout.isShort ? 13.5 : 15))
            .lineSpacing(layout.isShort ? 2 : 4)
            .foregroundStyle(Palette.label2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 640)
            .fixedSize(horizontal: false, vertical: true)
            points
            VStack(spacing: Spacing.small) {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 10)
                }
                .heroButton()
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("welcome.getStarted")
                Label("You’ll need an App Store Connect API key. It stays in this Mac’s Keychain.", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 2)
        }
        .padding(.top, layout.isShort ? 12 : 18)
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var points: some View {
        HStack(alignment: .top, spacing: 14) {
            WelcomePoint(
                systemImage: "globe",
                title: "Every storefront, one place",
                detail: "Your page in 175 countries and regions and every language, without opening App Store Connect.",
                showsDetail: layout.showsPointDetails
            )
            WelcomePoint(
                systemImage: "sparkle",
                title: "Suggestions, never surprises",
                detail: "Your AI assistant and Atlas’s own checks suggest changes. Nothing is accepted without you.",
                showsDetail: layout.showsPointDetails
            )
            WelcomePoint(
                systemImage: "arrow.up.to.line",
                title: "Push when you’re ready",
                detail: "Changes wait in Review & Push until you send them to App Store Connect.",
                showsDetail: layout.showsPointDetails
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 900)
    }
}

#Preview {
    WelcomeIntro(layout: WelcomeLayout(windowSize: CGSize(width: 1200, height: 780))) {}
        .frame(width: 1200, height: 380)
}
