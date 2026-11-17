//
//  AppEventMediaUploadAttributes.swift
//  Atlas
//

import Foundation

/// What an `appEventScreenshots` or `appEventVideoClips` resource says
/// while it's being uploaded: its parts to send, its asset type, and how
/// Apple's processing goes (`assetDeliveryState` for an image,
/// `videoDeliveryState` for a video, which also has `PROCESSING`).
struct AppEventMediaUploadAttributes: Decodable, Sendable {
    var fileName: String?
    var appEventAssetType: String?
    var uploadOperations: [ScreenshotUploadOperation]?
    var assetDeliveryState: ScreenshotDeliveryState?
    var videoDeliveryState: ScreenshotDeliveryState?

    /// The state that counts for this kind of resource.
    func deliveryState(isVideo: Bool) -> ScreenshotDeliveryState? {
        isVideo ? videoDeliveryState ?? assetDeliveryState : assetDeliveryState
    }
}
