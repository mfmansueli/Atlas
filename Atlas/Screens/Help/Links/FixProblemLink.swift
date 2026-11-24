//
//  FixProblemLink.swift
//  Atlas
//

import SwiftUI

/// "Fix a Problem" after an error: opens Atlas Help's Fix a problem article
/// at the heading for this kind of error, or at its top when the kind
/// isn't known. A plain button (README-DS §4).
struct FixProblemLink: View {
    let topic: HelpFixTopic?
    @Environment(\.openWindow) private var openWindow

    static let title = String(localized: "Fix a Problem", comment: "kind:link")

    var body: some View {
        Button(Self.title) {
            if let topic { HelpNavigation.shared.open(topic) } else { HelpNavigation.shared.open(HelpFixTopic.articleID) }
            openWindow(id: HelpCommands.windowID)
        }
        .plainButton()
        .font(.callout)
        .accessibilityHint(Text(hint))
        .accessibilityIdentifier("help.fixProblem")
    }

    private var hint: String {
        guard let topic else { return String(localized: "Opens Help’s Fix a problem.", comment: "kind:accessibility-label") }
        return String(localized: "Opens Help at “\(topic.heading)”.", comment: "kind:accessibility-label")
    }
}
