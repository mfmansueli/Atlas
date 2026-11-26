//
//  ActivityList.swift
//  Atlas
//

import SwiftUI

/// Review & Push's Activity tab (README-DS §15, board 90): every push from
/// this Mac, for all apps, newest first. Restore Previous Values puts the
/// old values on To Push and Restore Previous Screenshots… a locale's
/// kept set; neither pushes. "Show in Activity" at the end of a push opens
/// here on that push, tinted. With no pushes yet, the small empty state
/// (§14).
struct ActivityList: View {
    /// The pushes, newest first.
    let records: [PushRecord]
    /// The push to tint and scroll to.
    let highlightedID: PushRecord.ID?
    let onResults: () -> Void
    let onRestore: (PushRecord) -> Void
    /// Restore Previous Screenshots…, while the screenshots can be pushed.
    let onRestoreScreenshots: ((PushRecord) -> Void)?

    var body: some View {
        let now = Date.now
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(String(localized: "Activity", comment: "kind:sheet-title · Review & Push's Activity tab"))
                    .atlasTextStyle(.title2)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.medium)
            .padding(.bottom, Spacing.medium)
            Divider()
            if records.isEmpty {
                EmptyStateView(
                    String(localized: "Nothing pushed yet", comment: "kind:empty-state · Activity"),
                    systemImage: "clock",
                    text: String(
                        localized: "Pushes from this Mac show here, with what changed and a way to put the old values back.",
                        comment: "kind:description · Activity's empty state"
                    ),
                    size: .inline
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("activity.empty")
            } else {
                list(now: now)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(ActivityText(now: now).summary(of: records)))
        .accessibilityIdentifier("review.activity")
    }

    private func list(now: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(records) { record in
                        ActivityRow(
                            record: record,
                            isHighlighted: record.id == highlightedID,
                            now: now,
                            onResults: onResults,
                            onRestore: { onRestore(record) },
                            onRestoreScreenshots: onRestoreScreenshots.map { restore in { restore(record) } }
                        )
                        .id(record.id)
                        Divider()
                    }
                }
            }
            // On the push that just ended, at once: nothing animates on
            // opening.
            .onAppear {
                if let highlightedID { proxy.scrollTo(highlightedID, anchor: .center) }
            }
        }
    }

    private var subtitle: String {
        records.isEmpty
            ? String(localized: "Every push from this Mac shows here.", comment: "kind:description · Activity, nothing pushed yet")
            : String(
                localized: "Every push from this Mac, for all your apps. Restoring puts the old values in Review & Push; nothing is pushed until you push it.",
                comment: "kind:description · Activity"
            )
    }
}
