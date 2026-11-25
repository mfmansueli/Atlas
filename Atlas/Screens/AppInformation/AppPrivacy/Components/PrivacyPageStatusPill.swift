//
//  PrivacyPageStatusPill.swift
//  Atlas
//

import SwiftUI

/// The status beside App Privacy's tabs: amber while questions or
/// suggestions wait, accent when ready for App Store Connect, green once
/// published there.
struct PrivacyPageStatusPill: View {
    let status: PrivacyPageStatus

    var body: some View {
        Group {
            if status.tone == .published {
                // As `AppPrivacyStatusPill` draws "published".
                Text(status.text)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Palette.ok)
                    .padding(.horizontal, 7)
                    .frame(minHeight: 20)
                    .background(Palette.okTint, in: Capsule())
            } else {
                Pill(text: status.text, style: style)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("App Privacy: \(status.text)", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("appInformation.appPrivacy.status")
    }

    private var style: PillStyle {
        switch status.tone {
        case .ready: .accent
        case .waiting, .outOfDate: .warning
        case .neutral, .published: .neutral
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        PrivacyPageStatusPill(status: PrivacyPageStatus(status: .inProgress, openQuestions: 1, unreviewed: 3))
        PrivacyPageStatusPill(status: PrivacyPageStatus(status: .done, openQuestions: 0, unreviewed: 0))
        PrivacyPageStatusPill(status: PrivacyPageStatus(status: .published(.now), openQuestions: 0, unreviewed: 0))
    }
    .padding()
}
