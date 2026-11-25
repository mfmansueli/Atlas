//
//  ConnectBeforeYouStart.swift
//  Atlas
//

import SwiftUI

/// "Before you start" on Connect (README-Welcome): making the key in three
/// steps, Open App Store Connect, and Show Me How, which opens Atlas Help's
/// "Connect to App Store Connect" in its own window, so it can stay open
/// next to the browser.
struct ConnectBeforeYouStart: View {
    var showsExplanation = true
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    static let integrationsURL = URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!
    /// The Help article Show Me How opens.
    static let helpArticleID = "connect"

    private let steps: [LocalizedStringKey] = [
        "Open **Users and Access**, then **Integrations**.",
        "Create a **Team Key** with **Admin** access.",
        "**Download** the key file. Apple shows it only once.",
    ]

    var body: some View {
        Card(padding: showsExplanation ? Spacing.large : Spacing.medium) {
            VStack(alignment: .leading, spacing: showsExplanation ? Spacing.medium : Spacing.small) {
                ConnectCardHeading(
                    title: "Before you start",
                    subtitle: "Make a key in App Store Connect. About two minutes.",
                    showsSubtitle: showsExplanation
                )
                VStack(alignment: .leading, spacing: showsExplanation ? Spacing.small : Spacing.xSmall) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                            Text(verbatim: "\(index + 1)")
                                .atlasTextStyle(.callout)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(Palette.accentText)
                                .frame(width: Metrics.symbolColumn, height: Metrics.symbolColumn)
                                .background(Palette.accentTint, in: Circle())
                                .accessibilityHidden(true)
                            Text(step)
                                .atlasTextStyle(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("connect.steps")
                Spacer(minLength: 0)
                HStack(spacing: Spacing.xSmall) {
                    Button {
                        openURL(Self.integrationsURL)
                    } label: {
                        Label("Open App Store Connect", systemImage: "arrow.up.right.square")
                    }
                    .secondaryButton()
                    .accessibilityIdentifier("connect.openAppStoreConnect")
                    Button("Show Me How") {
                        HelpNavigation.shared.open(Self.helpArticleID)
                        openWindow(id: HelpCommands.windowID)
                    }
                    .plainButton()
                    .accessibilityHint(Text("Opens Atlas Help next to this window."))
                    .accessibilityIdentifier("connect.showMeHow")
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    ConnectBeforeYouStart()
        .padding()
        .frame(width: 400)
}
