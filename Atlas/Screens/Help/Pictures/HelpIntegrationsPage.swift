//
//  HelpIntegrationsPage.swift
//  Atlas
//

import SwiftUI

/// Step 1's picture: Users and Access in App Store Connect's bar, then its
/// Integrations tab, both in the ring.
struct HelpIntegrationsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HelpPageNav(ringsUsersAndAccess: true)
            HStack(spacing: Spacing.large) {
                Text(AppStoreConnectPageWords.people)
                Text(AppStoreConnectPageWords.sandbox)
                Text(AppStoreConnectPageWords.integrations)
                    .helpPictureRing()
            }
            .fixedSize()
            .foregroundStyle(Palette.label2)
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.separator).frame(height: 0.5)
            }
            // The page under the tabs, as grey lines.
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                line(Metrics.helpPictureLongLine)
                line(Metrics.helpPictureShortLine)
            }
            .padding(.horizontal, Spacing.medium)
        }
    }

    private func line(_ width: CGFloat) -> some View {
        Capsule()
            .fill(Palette.fill2)
            .frame(width: width, height: Metrics.helpPictureLine)
    }
}
