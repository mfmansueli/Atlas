//
//  PushNoticeBanner.swift
//  Atlas
//

import SwiftUI

/// The workspace banner after a push stopped or partly failed: offline,
/// rate limited, an API error with Apple's text, or "2 of 26 failed" with
/// Review Failed.
struct PushNoticeBanner: View {
    let notice: PushNotice
    let push: PushController
    let onReviewFailed: () -> Void

    var body: some View {
        Banner(kind: notice.kind, title: notice.title, message: notice.message, fixTopic: fixTopic) {
            if case .partialFailure = notice {
                Button("Review Failed", action: onReviewFailed)
                    .accessibilityIdentifier("banner.reviewFailed")
            }
            Button {
                push.dismissNotice()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Dismiss"))
        }
        .accessibilityIdentifier("workspace.banner")
    }

    /// A push's problems are Apple's: Fix a Problem lands on their heading.
    private var fixTopic: HelpFixTopic? {
        switch notice.kind {
        case .partialFailure: .pushStopped
        case .rateLimited: .hourlyLimit
        case .offline: .offline
        case .apiError, .info, .warning: nil
        }
    }
}
