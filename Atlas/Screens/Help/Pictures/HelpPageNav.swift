//
//  HelpPageNav.swift
//  Atlas
//

import SwiftUI

/// App Store Connect's bar across the top of its pages, in a Help picture.
/// What doesn't fit the picture runs off its edge, as in a narrow browser.
struct HelpPageNav: View {
    var ringsUsersAndAccess = false

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(verbatim: "App Store Connect")
                .fontWeight(.semibold)
                .padding(.trailing, Spacing.xxSmall)
            Text(AppStoreConnectPageWords.apps)
            Text(AppStoreConnectPageWords.analytics)
            Text(AppStoreConnectPageWords.usersAndAccess)
                .helpPictureRing(isOn: ringsUsersAndAccess)
            Text(AppStoreConnectPageWords.business)
        }
        .fixedSize()
        .padding(.horizontal, Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
