//
//  HelpFixLinksDebugView.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `help-fix-links`: an error from Apple as the error template shows it,
/// a load failure and an offline banner, each with Fix a Problem, and a
/// section title with its ?.
struct HelpFixLinksDebugView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            WorkspaceToolbarTitle(title: "Subscription Pricing", status: WorkspaceSectionStatus(section: .subscriptionPricing)) {}
            ErrorCopyMessage(copy: AppleErrorCopy(
                String(localized: "Prices didn’t push."),
                error: AppStoreConnectError.forbidden(detail: "The API key in use does not allow this request")
            ))
            .accessibilityIdentifier("debug.fix.message")
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the reviews"), message: "HTTP 503") {
                Button("Try Again") {}
            }
            .accessibilityIdentifier("debug.fix.banner")
            Banner(kind: .offline, title: String(localized: "You’re offline."), message: String(localized: "Changes wait in Review & Push."))
            Spacer()
        }
        .padding(Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
    }
}
#endif
