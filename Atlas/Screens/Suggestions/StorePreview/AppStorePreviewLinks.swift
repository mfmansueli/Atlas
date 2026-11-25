//
//  AppStorePreviewLinks.swift
//  Atlas
//

import Foundation

/// Where each part of the App Store page preview opens: the section editing
/// it (the Overview's preview links every part; the Store Page's only the
/// screenshots and the event, the rest being the editor beside it).
struct AppStorePreviewLinks {
    var storePage: AppStorePreviewLink?
    var appInformation: AppStorePreviewLink?
    var screenshots: AppStorePreviewLink?
    var pricing: AppStorePreviewLink?
    /// The live event's card: In-App Events on that event.
    var inAppEvent: ((InAppEvent.ID) -> Void)?
    /// The App Preview's play button: Screenshots on that language and
    /// device.
    var appPreview: ((_ locale: String, _ displayType: ScreenshotDisplayType) -> Void)?
}
