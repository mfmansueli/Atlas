//
//  ExtrasPushProgressRow.swift
//  Atlas
//

import SwiftUI

/// One header, search image or App Preview in a running push: its state,
/// the image or the movie's first frame (a click opens it large), what
/// it's doing ("Uploading 42% · 3.1 MB of 7.4 MB", "Apple is processing
/// it · 0:42", "Waiting · 6 ahead") or why it failed, and its step on the
/// right with a bar while it uploads. In flight, its clock ticks.
struct ExtrasPushProgressRow: View {
    let run: ExtrasPushRun
    let item: ExtrasPushItem
    var thumbnailWidth: CGFloat? = 32
    var onOpen: (() -> Void)?

    var body: some View {
        if run.activities[item.id] != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                row(now: context.date)
            }
        } else {
            row(now: .now)
        }
    }

    private func row(now: Date) -> some View {
        let status = run.status(of: item)
        let detail = status.failureReason ?? run.stepDetail(of: item, now: now) ?? run.queueTitle(of: item)
        return PushProgressRowLayout(
            state: PushProgressState(status), title: Text(item.title), detail: detail, trailing: status.title,
            fraction: Self.fraction(status), thumbnailWidth: thumbnailWidth,
            accessibilityText: [item.title, status.title, detail].compactMap(\.self).joined(separator: ", "),
            identifier: "push.extras.row.\(item.id)", onOpen: onOpen
        ) {
            PushFileThumbnail(url: item.fileURL, isVideo: item.kind.media == .video, pixelSize: item.pixelSize)
        }
    }

    private static func fraction(_ status: ExtrasPushStatus) -> Double? {
        if case let .uploading(fraction) = status { return fraction }
        return nil
    }
}
