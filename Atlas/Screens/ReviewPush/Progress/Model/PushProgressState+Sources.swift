//
//  PushProgressState+Sources.swift
//  Atlas
//

import Foundation

/// Each push's own statuses, as the progress sheet counts them. A change
/// App Store Connect has a different value for (a conflict) wasn't sent:
/// it waits in review.
extension PushProgressState {
    init(_ status: PushItemStatus) {
        switch status {
        case .queued: self = .waiting
        case .sending: self = .sending
        case .done: self = .done
        case let .failed(reason): self = .failed(reason)
        case .conflict, .notSent: self = .notSent
        }
    }

    init(_ status: ScreenshotUploadStatus) {
        switch status {
        case .queued: self = .waiting
        case .keepingCopy, .reserving, .uploading, .committing: self = .sending
        case .done: self = .done
        case let .failed(reason): self = .failed(reason)
        case .cancelled, .notSent: self = .notSent
        }
    }

    init(_ status: ExtrasPushStatus) {
        switch status {
        case .waiting: self = .waiting
        case .preparing, .uploading, .processing, .placing: self = .sending
        case .done: self = .done
        case let .failed(reason): self = .failed(reason)
        case .cancelled: self = .notSent
        }
    }
}
