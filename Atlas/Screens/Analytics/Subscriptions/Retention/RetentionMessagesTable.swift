//
//  RetentionMessagesTable.swift
//  Atlas
//

import SwiftUI

/// Save rate by message, each against No Message (Apple's plain screen).
struct RetentionMessagesTable: View {
    let report: RetentionReport
    let onAct: (FindingAction, String) -> Void

    private static let widths: [CGFloat] = [130, 70, 70, 110, 170]

    var body: some View {
        AnalyticsBox(title: String(localized: "Save rate by message")) {
            AnalyticsColumns(
                titles: [
                    String(localized: "Message"), String(localized: "Type"), String(localized: "Opened"), String(localized: "Stayed"),
                    String(localized: "Save rate"), String(localized: "Against No Message"),
                ],
                widths: Self.widths
            )
            ForEach(report.messages) { message in
                Divider()
                AnalyticsColumns(
                    [
                        AnyView(Text(message.name).fontWeight(message.isNoMessage ? .regular : .medium)),
                        AnyView(Text(message.typeTitle).foregroundStyle(Palette.label2)),
                        AnyView(Text(AnalyticsText.count(message.opened))),
                        AnyView(Text(AnalyticsText.count(message.stayed))),
                        AnyView(RateLabel(rate: message.rate)),
                        AnyView(against(message)),
                    ],
                    widths: Self.widths
                )
                .accessibilityIdentifier("analytics.retention.message.\(message.id)")
            }
            HStack {
                Spacer()
                Button("Open Retention") { onAct(.retention, String(localized: "Save rates are from Analytics: the last 28 complete days.")) }
                    .controlSize(.regular)
                    .accessibilityIdentifier("analytics.retention.openRetention")
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
        }
    }

    @ViewBuilder
    private func against(_ message: RetentionReport.Message) -> some View {
        if message.isNoMessage {
            Text("The reference").foregroundStyle(Palette.label2)
        } else if let outcome = message.againstNoMessage {
            Text(outcome.verdict)
                .foregroundStyle(outcome.isHigher ? Palette.ok : outcome.isLower ? Palette.err : Palette.label2)
        } else {
            Text("—").foregroundStyle(Palette.label2)
        }
    }
}
