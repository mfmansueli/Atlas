//
//  PrivacyOutOfDateBanner.swift
//  Atlas
//

import SwiftUI

/// After Mark as Published, a scan or an edit changed the answers: App
/// Store Connect may no longer match.
struct PrivacyOutOfDateBanner: View {
    let date: Date
    let onOpenChecklist: () -> Void

    var body: some View {
        PrivacyNotice(isWarning: true) {
            Text("**Out of date with App Store Connect.** Answers changed since you published them on \(date.formatted(date: .abbreviated, time: .omitted)). Review them, then update App Store Connect with the checklist.")
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            Button(String(localized: "Open Checklist"), action: onOpenChecklist)
                .accessibilityIdentifier("appInformation.appPrivacy.openChecklist")
        }
        .accessibilityIdentifier("appInformation.appPrivacy.outOfDate")
    }
}
