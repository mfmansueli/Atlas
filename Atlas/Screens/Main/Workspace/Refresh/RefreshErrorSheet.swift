//
//  RefreshErrorSheet.swift
//  Atlas
//

import SwiftUI

/// Details… after a Refresh that failed (README-DS §15): what went wrong
/// in Atlas's words, when what shows is from and that nothing the person
/// changed is lost. Apple's own text and code only under Show Details.
/// Try Again refreshes; Close leaves things as they are.
struct RefreshErrorSheet: View {
    let copy: AppleErrorCopy
    let lastUpdated: Date?
    let onTryAgain: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsDetails = false

    private var detailsTitle: String {
        showsDetails
            ? String(localized: "Hide Details", comment: "kind:button · Refresh's error sheet")
            : String(localized: "Show Details", comment: "kind:button · Refresh's error sheet")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(String(localized: "Couldn’t Update from App Store Connect", comment: "kind:sheet-title · Refresh's error"))
                .atlasTextStyle(.title2)
                .accessibilityAddTraits(.isHeader)
            Text(RefreshText(now: .now).errorText(copy, lastUpdated: lastUpdated))
                .atlasTextStyle(.body)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("refresh.error.text")
            if let details = copy.details {
                Button(detailsTitle) { showsDetails.toggle() }
                    .plainButton()
                    .accessibilityIdentifier("refresh.error.details")
                if showsDetails {
                    Text(details)
                        .atlasTextStyle(.callout)
                        .monospaced()
                        .foregroundStyle(Palette.label2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("refresh.error.code")
                }
            }
            HStack(spacing: Spacing.small) {
                if let topic = copy.fixTopic {
                    FixProblemLink(topic: topic)
                }
                Spacer()
                Button(String(localized: "Close", comment: "kind:button · Refresh's error sheet")) { dismiss() }
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("refresh.error.close")
                Button(String(localized: "Try Again", comment: "kind:button · Refresh's error sheet")) {
                    dismiss()
                    onTryAgain()
                }
                .primaryButton(isDefault: true)
                .accessibilityIdentifier("refresh.error.tryAgain")
            }
            .padding(.top, Spacing.small)
        }
        .padding(Spacing.xLarge)
        .frame(width: 460)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("refresh.error")
    }
}

#Preview {
    RefreshErrorSheet(
        copy: AppleErrorCopy(summary: "App Store Connect didn’t answer in time.", details: "The request timed out. (URLError -1001)"),
        lastUpdated: .now.addingTimeInterval(-600)
    ) {}
}
