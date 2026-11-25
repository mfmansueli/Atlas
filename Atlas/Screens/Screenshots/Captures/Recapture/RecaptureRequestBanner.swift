//
//  RecaptureRequestBanner.swift
//  Atlas
//

import SwiftUI

/// Over Screenshots while the assistant waits on a request to redo
/// captures: "Claude Code wants to redo 18 captures in ja: phrases
/// rewritten in d038b58", with Accept and Decline.
struct RecaptureRequestBanner: View {
    let studio: ScreenshotStudioModel
    let request: AutopilotRecaptureRequest
    @State private var isAccepting = false

    var body: some View {
        Banner(kind: .info, title: request.headline, message: request.evidence.map { String(localized: "Evidence: \($0)") }, isInline: true) {
            HStack(spacing: Spacing.small) {
                if isAccepting { ProgressView().controlSize(.small) }
                Button("Decline") { studio.declineRecapture(request) }
                    .accessibilityIdentifier("screenshots.recaptureRequest.decline")
                Button("Accept") {
                    isAccepting = true
                    Task {
                        await studio.acceptRecapture(request)
                        isAccepting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAccepting)
                .help(request.page == nil
                    ? Text("Claude Code recaptures only these. Nothing is sent.")
                    : Text("Claude Code captures these screens again. Nothing is sent."))
                .accessibilityIdentifier("screenshots.recaptureRequest.accept")
            }
        }
        .accessibilityIdentifier("screenshots.recaptureRequest")
    }
}
