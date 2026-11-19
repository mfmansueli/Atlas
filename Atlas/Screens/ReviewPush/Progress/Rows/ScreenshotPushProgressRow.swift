//
//  ScreenshotPushProgressRow.swift
//  Atlas
//

import SwiftUI

/// One image in a running push: its state, a tiny thumbnail (a click
/// opens it large), "Arabic · iPhone · 1 Today" with the reason in red
/// when it failed, and the step on the right: Queued, Reserving…,
/// Uploading 64% with a bar, Committing…, Done · Apple is processing,
/// Failed, Cancelled.
struct ScreenshotPushProgressRow: View {
    let item: ScreenshotUploadItem
    let image: CGImage?
    var thumbnailWidth: CGFloat? = 32
    var onOpen: (() -> Void)?

    var body: some View {
        PushProgressRowLayout(
            state: PushProgressState(item.status), title: Text(item.title), detail: item.status.failureText ?? item.note,
            trailing: item.status.stepTitle, fraction: item.status.uploadFraction, thumbnailWidth: thumbnailWidth,
            accessibilityText: [item.title, item.status.stepTitle, item.status.failureText ?? item.note].compactMap(\.self)
                .joined(separator: ", "),
            identifier: "push.shots.row.\(ScreenshotReviewItemCard.identifier(item.plan))", onOpen: onOpen
        ) {
            ScreenshotThumbnail(
                image: image,
                width: min(24, item.plan.cell.displayType.thumbnailWidth(phone: 18, tablet: 24)),
                aspect: ScreenshotThumbnail.aspect(of: item.plan)
            )
        }
    }
}
