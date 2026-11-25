//
//  ProductPagesEmptyView.swift
//  Atlas
//

import SwiftUI

/// No pages yet (board 74 · 2): the three uses of a custom product page in
/// one sentence, naming New Page… in the toolbar (board 80) and
/// Autopilot's Suggest Pages…, and Apple's limit in the small line. No
/// button of its own: both are already on screen.
struct ProductPagesEmptyView: View {
    let appName: String
    var size: EmptyStateSize = .page

    var body: some View {
        EmptyStateView(
            String(localized: "No custom product pages yet", comment: "kind:empty-state"),
            systemImage: AppWorkspaceSection.productPages.systemImage,
            text: String(localized: """
            Another version of \(appName)’s page with its own link: use it in an ad or a newsletter, show it for the searches \
            you choose, and change the screenshots people see first. Click New Page to make one, or Suggest Pages for ideas \
            from your assistant.
            """, comment: "kind:description"),
            note: String(localized: "Up to 70 pages. Each is reviewed on its own, with no new app version.", comment: "kind:description"),
            size: size
        )
        .accessibilityIdentifier("pages.empty")
    }
}
