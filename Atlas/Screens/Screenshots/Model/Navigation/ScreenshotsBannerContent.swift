//
//  ScreenshotsBannerContent.swift
//  Atlas
//

import Foundation

/// The banner over the Sets matrix: no version to push to (a warning, with
/// the next version's number to create), a new version that waits in
/// Review & Push, or renders failing their checks (an error naming the
/// first one).
enum ScreenshotsBannerContent: Hashable, Sendable {
    case noVersion(title: String, message: String, next: String)
    /// The live version can't change, and the next one waits in Review &
    /// Push: pushing it makes the version screenshots go to. Text only: the
    /// toolbar's "N not pushed" opens Review & Push.
    case versionQueued(title: String, message: String)
    case failedChecks(title: String, message: String, first: ScreenshotCellKey)
}
