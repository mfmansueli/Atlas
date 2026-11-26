//
//  AnalyticsNoticeBanner.swift
//  Atlas
//

import SwiftUI

/// Analytics' one notice above the content (README-DS §16): the design
/// system's banner, with the notice's button (Check Again, Add Vendor
/// Number…, See How to Fix…, Reports from Apple…).
struct AnalyticsNoticeBanner: View {
    let notice: AnalyticsPageNotice
    let appName: String
    var now: Date = .now
    /// A check is running: Check Again waits for it.
    var isChecking = false
    let onAction: (AnalyticsNoticeAction) -> Void

    var body: some View {
        Banner(kind: notice.bannerKind, title: notice.title(appName: appName), message: notice.message(now: now)) {
            if let action = notice.action {
                Button(action.title) { onAction(action) }
                    .disabled(action == .checkAgain && isChecking)
                    .accessibilityIdentifier(action.identifier)
            }
        }
        // The banner keeps its own inset for a page's full width; here the
        // page's margin is already there.
        .padding(.horizontal, -Spacing.large)
        .padding(.vertical, -Spacing.small)
        .accessibilityIdentifier(notice.identifier)
    }
}
