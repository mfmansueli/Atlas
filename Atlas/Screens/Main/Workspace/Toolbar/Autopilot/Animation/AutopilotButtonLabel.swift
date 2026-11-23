//
//  AutopilotButtonLabel.swift
//  Atlas
//

import SwiftUI

/// The inside of the Autopilot button's main half, for each look: the
/// purple sparkle and the action; the twinkling sparkle and what runs; the
/// green check and what's done; what the run needs, on purple; what
/// stopped; or Reply Automatically's green dot.
struct AutopilotButtonLabel: View {
    let look: AutopilotButtonLook
    /// The section's action, while idle.
    var title: String?
    var isPro = false
    /// The sparkle or the check alone, when the toolbar is out of room.
    var isCompact = false

    var body: some View {
        HStack(spacing: 6) {
            switch look {
            case .idle:
                AutopilotSparkle()
                if !isCompact, let title {
                    Text(title).foregroundStyle(Palette.ai)
                }
                if isPro { ProChip() }
            case let .working(text, _), let .counting(text, _):
                AutopilotSparkle(isWorking: true)
                if !isCompact { Text(text).foregroundStyle(Palette.label) }
            case let .done(text):
                AutopilotDoneMark()
                if !isCompact { Text(text).foregroundStyle(Palette.ok) }
            case let .needsYou(text):
                AutopilotSparkle(color: .white)
                if !isCompact {
                    Text(text)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            case let .failed(text):
                AutopilotSparkle(color: Palette.label2)
                if !isCompact { Text(text).foregroundStyle(Palette.label) }
            case let .autoReplyOn(text):
                Circle()
                    .fill(Palette.ok)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                if !isCompact { Text(text).foregroundStyle(Palette.label) }
            }
        }
        .font(.body.weight(.medium))
        .lineLimit(1)
        .frame(maxWidth: 280)
    }
}
