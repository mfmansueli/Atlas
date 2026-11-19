//
//  PushProgressFailures.swift
//  Atlas
//

import SwiftUI

/// Each reason something in the push failed, once, with the rows it
/// stopped: "2 failed · STATE_ERROR: Not now." over "Subtitle · German and
/// Subtitle · French". Scrolls past a few reasons, so the list keeps its
/// room.
struct PushProgressFailures: View {
    let groups: [PushProgressFailureGroup]

    private static let maxHeight: CGFloat = 112

    var body: some View {
        if !groups.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(groups) { group in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(Palette.danger)
                                .frame(width: 14)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(group.titles.count) failed · \(group.reason)")
                                    .foregroundStyle(Palette.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                Text(group.itemsTitle)
                                    .foregroundStyle(Palette.label2)
                                    .lineLimit(2)
                                    .help(group.titles.joined(separator: "\n"))
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .font(.caption)
            }
            .scrollBounceBehavior(.basedOnSize)
            // As tall as the reasons, up to the most it takes.
            .frame(maxHeight: Self.maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("push.failures")
        }
    }
}
