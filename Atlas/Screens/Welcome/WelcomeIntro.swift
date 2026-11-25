//
//  WelcomeIntro.swift
//  Atlas
//

import SwiftUI

/// The words under the welcome header: what Atlas is in two lines (the
/// quiet one hides below 680 points of height), three points, Get
/// Started, and the one thing people worry about (the API key stays in
/// this Mac's Keychain).
struct WelcomeIntro: View {
    let layout: WelcomeLayout
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: layout.isShort ? 10 : 14) {
            Text("Welcome to Atlas")
                .font(layout.isShort ? .largeTitle.bold() : .display)
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.title")
            lines
            points
            VStack(spacing: Spacing.small) {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 10)
                }
                .heroButton()
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("welcome.getStarted")
                Label("You’ll need an App Store Connect key. It never leaves this Mac.", systemImage: "lock")
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

    /// Two lines (README-Welcome, 22 November): what Atlas does in the main
    /// text colour, then a quieter one that hides below 680 points.
    private var lines: some View {
        VStack(spacing: Spacing.xxSmall) {
            Text("Your App Store words, screenshots and prices, right in every country.")
                .atlasTextStyle(layout.isShort ? .title3 : .title2)
                .fontWeight(.regular)
                .foregroundStyle(Palette.label)
                .accessibilityIdentifier("welcome.tagline")
            if layout.showsQuietLine {
                Text("Atlas suggests, you review, and one push sends it to App Store Connect.")
                    .atlasTextStyle(.body)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("welcome.quietLine")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 640)
        .fixedSize(horizontal: false, vertical: true)
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
                detail: "Your assistant and Atlas’s checks suggest changes. Nothing is accepted without you.",
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
