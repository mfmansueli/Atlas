//
//  PushProgressRow.swift
//  Atlas
//

import SwiftUI

/// One change in a running push: queued ○, sending (spinner), done ✓, or
/// failed with Apple's code and detail underneath. A change with an option
/// says its step on the right instead of its value: Queued → Sending… →
/// Publishing… → Published, or Saved as a draft. An event's card or
/// details page shows its image or video, which a click opens large.
struct PushProgressRow: View {
    let item: PushItem
    /// The event art it uploads, if it's one.
    var artwork: InAppEventArtworkPush?
    var thumbnailWidth: CGFloat?
    var onOpen: (() -> Void)?

    var body: some View {
        if let artwork {
            layout(onOpen: onOpen) {
                PushFileThumbnail(
                    url: URL(fileURLWithPath: artwork.path), isVideo: artwork.isVideo,
                    pixelSize: InAppEventArtworkRules.minimumSize(for: artwork.kind)
                )
            }
        } else {
            layout(onOpen: nil) { EmptyView() }
        }
    }

    private func layout(onOpen: (() -> Void)?, @ViewBuilder thumbnail: @escaping () -> some View) -> some View {
        PushProgressRowLayout(
            state: PushProgressState(item.status), isConflict: item.status == .conflict,
            title: Text("\(Text(item.change.title)) \(Text("· \(item.change.group)").foregroundStyle(Palette.label2))"),
            detail: detail, trailing: trailingText, thumbnailWidth: thumbnailWidth,
            accessibilityText: String(localized: "\(item.change.title) · \(item.change.group), \(statusText), \(trailingText)")
                + (detail.map { ", \($0)" } ?? ""),
            identifier: "push.row.\(item.id)", onOpen: onOpen, thumbnail: thumbnail
        )
    }

    /// The new value, or the option's step for a change that has one.
    private var trailingText: String {
        guard let option = item.change.option else { return item.change.newValue }
        switch item.status {
        case .queued: return String(localized: "Queued")
        case .sending: return item.isSendingOption ? option.progressTitle : String(localized: "Sending…")
        case .done: return option.finishedTitle
        case .failed, .conflict, .notSent: return item.change.newValue
        }
    }

    private var detail: String? {
        switch item.status {
        case let .failed(text): text
        case .conflict: String(localized: "Changed in App Store Connect since your last fetch. It's back in review.")
        case let .notSent(reason): reason
        case .sending: item.progressNote
        case .queued, .done: nil
        }
    }

    private var statusText: String {
        switch item.status {
        case .queued: String(localized: "Queued")
        case .sending: String(localized: "Sending")
        case .done: String(localized: "Done")
        case .failed: String(localized: "Failed")
        case .conflict: String(localized: "Conflict")
        case .notSent: String(localized: "Not sent")
        }
    }
}
