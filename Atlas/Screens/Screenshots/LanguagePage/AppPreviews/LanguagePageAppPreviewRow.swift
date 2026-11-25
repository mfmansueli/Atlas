//
//  LanguagePageAppPreviewRow.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// The App Previews the language page's row starts with, on every device
/// that has them (Mac and Apple Vision Pro too, not only iPhone and iPad):
/// the set as it ends after the push when a change waits in Review & Push,
/// else what's live, in order. The same in Now and Suggested.
enum LanguagePageAppPreviewRow {
    /// Each App Preview of the set: `queued`'s places when a change waits,
    /// else `live`'s (one without a poster per App Preview in a set read
    /// before Atlas kept each preview).
    static func items(
        queued: AppPreviewSetPush.Content?, live: LiveAppPreviewSet?, locale: String, displayType: ScreenshotDisplayType
    ) -> [LanguagePageAppPreview] {
        let fallback = aspect(of: displayType)
        if let queued {
            let previews = live?.previews ?? []
            return queued.slots.enumerated().map { index, slot in
                let shown = slot.liveID.flatMap { id in previews.first { $0.id == id } }
                return LanguagePageAppPreview(
                    id: slot.file?.path ?? slot.liveID ?? "\(queued.localizationID).\(index)", position: index, count: queued.slots.count,
                    locale: locale, displayType: displayType, fileName: slot.fileName, live: shown,
                    fileURL: slot.file.map { URL(fileURLWithPath: $0.path) }, aspect: aspect(of: shown) ?? fallback
                )
            }
        }
        guard let live else { return [] }
        let previews: [LiveAppPreview?] = live.previews ?? Array(repeating: nil, count: live.previewCount)
        return previews.enumerated().map { index, preview in
            LanguagePageAppPreview(
                id: preview?.id ?? "\(live.id).\(index)", position: index, count: previews.count, locale: locale,
                displayType: displayType, fileName: preview?.fileName ?? "", live: preview, fileURL: nil,
                aspect: aspect(of: preview) ?? fallback
            )
        }
    }

    /// The poster frame's height ÷ width, when App Store Connect gave it.
    static func aspect(of preview: LiveAppPreview?) -> CGFloat? {
        guard let size = preview?.posterPixelSize, size.width > 0, size.height > 0 else { return nil }
        return CGFloat(size.height) / CGFloat(size.width)
    }

    /// The shape of the device's App Previews: iPhone and iPad portrait at
    /// their exact size; Mac, Apple TV and Apple Vision Pro 16:9 (1920 ×
    /// 1080); any other device its screenshots' shape.
    static func aspect(of displayType: ScreenshotDisplayType) -> CGFloat {
        if let size = AppPreviewSpec.spec(for: displayType, landscape: false)?.pixelSize, size.width > 0 {
            return CGFloat(size.height) / CGFloat(size.width)
        }
        switch displayType {
        case .mac, .appleTV, .visionPro:
            return 1080 / 1920
        default:
            let size = displayType.defaultPixelSize
            return CGFloat(size.height) / CGFloat(max(size.width, 1))
        }
    }
}
