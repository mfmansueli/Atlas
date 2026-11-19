//
//  PushProgressKind.swift
//  Atlas
//

import Foundation

/// What one row of a push sends, as the title counts it: a change (a text,
/// price, answer…), an image (a screenshot, header or search image, event
/// art) or a video (an App Preview, a motion loop, an event video).
enum PushProgressKind: Hashable, Sendable, CaseIterable {
    case change
    case image
    case video

    /// "1 change", "40 images", "3 videos".
    func countTitle(_ count: Int) -> String {
        if count == 1 {
            switch self {
            case .change: return String(localized: "1 change")
            case .image: return String(localized: "1 image")
            case .video: return String(localized: "1 video")
            }
        }
        switch self {
        case .change: return String(localized: "\(count) changes")
        case .image: return String(localized: "\(count) images")
        case .video: return String(localized: "\(count) videos")
        }
    }
}
