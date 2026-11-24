//
//  NominationCard.swift
//  Atlas
//

import SwiftUI

/// One nomination in the gallery: its type, name, apps, dates, devices,
/// state, and the one line of what needs the person.
struct NominationCard: View {
    let nomination: Nomination
    let apps: String
    let need: NominationNeed
    let isQueued: Bool
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            Card {
                HStack(spacing: Spacing.xSmall) {
                    Label(nomination.content.type?.title ?? String(localized: "No type yet", comment: "kind:empty-state"),
                          systemImage: nomination.content.type?.systemImage ?? "rosette")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xSmall)
                    if isQueued {
                        Pill(text: String(localized: "Not pushed", comment: "kind:pill"), style: .accent)
                    }
                    NominationStatePill(nomination: nomination)
                }
                Text(nomination.displayName)
                    .font(.headline)
                    .foregroundStyle(Palette.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(apps)
                    Text(NominationDayText.dates(nomination.content))
                    Text(NominationDevice.list(nomination.content.devices))
                }
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                NominationNeedLine(need: need)
            }
            .opacity(nomination.state == .archived ? 0.75 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.accent, lineWidth: isHovered ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("nominations.card")
    }

    private var accessibilityText: String {
        let state = NominationStatePill.text(for: nomination)
        let queued = isQueued ? String(localized: ", not pushed", comment: "kind:accessibility-label") : ""
        return "\(nomination.displayName), \(state)\(queued). \(need.text)"
    }
}
