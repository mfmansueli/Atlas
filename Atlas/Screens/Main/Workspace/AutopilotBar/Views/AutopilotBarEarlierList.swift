//
//  AutopilotBarEarlierList.swift
//  Atlas
//

import SwiftUI

/// “Earlier today” in the open bar (board 80): each request that finished,
/// what it made, and Show, which opens where its suggestions wait.
struct AutopilotBarEarlierList: View {
    let items: [AutopilotBarFinished]
    let onShow: (AutopilotBarFinished) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Earlier today", comment: "kind:title · the open Autopilot bar's finished requests")
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(Palette.label2)
                .padding(.horizontal, Spacing.small)
                .accessibilityAddTraits(.isHeader)
            ForEach(items) { item in
                HStack(spacing: Spacing.small) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.ok)
                        .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                        .accessibilityHidden(true)
                    Text(item.what)
                        .atlasTextStyle(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let result = item.result {
                        Text(result)
                            .atlasTextStyle(.callout)
                            .foregroundStyle(Palette.label2)
                            .fixedSize()
                    }
                    Button(String(localized: "Show", comment: "kind:button · a finished Autopilot request")) { onShow(item) }
                        .plainButton()
                        .fixedSize()
                        .accessibilityIdentifier("autopilotBar.earlier.show")
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxSmall)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilotBar.earlier")
    }
}
