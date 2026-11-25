//
//  ReviewShotSizeCopy.swift
//  Atlas
//

import Foundation
import ImageIO

/// The one 640 × 920 copy Atlas offers when Apple refuses a review
/// screenshot's dimensions (README — Pricing: review screenshots, “What this
/// changes”): Apple documents no size, and 640 × 920 px is the only one
/// developers report as accepted, so the card says that and offers it once.
/// A refusal of the copy itself offers nothing more.
enum ReviewShotSizeCopy {
    /// What the card offers for a queued review screenshot.
    enum Offer: Equatable {
        /// Apple refused this file's dimensions: “Use a 640 × 920 Copy”.
        /// `details` is what it said.
        case copy(details: String)
        /// It refused the 640 × 920 copy too.
        case copyRefused
    }

    static let size = PixelSize(width: 640, height: 920)

    /// Whether an error from App Store Connect is about the image's size
    /// (“IMAGE_INCORRECT_DIMENSIONS”, “incorrect size”, “wrong
    /// dimensions”).
    static func isAboutSize(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return ["dimension", "incorrect size", "wrong size", "invalid size", "image size", "size of the image"].contains { lowered.contains($0) }
    }

    /// The offer for `change`, from the last push that refused it: only
    /// when that push sent this very file and Apple's reason was its size.
    static func offer(for change: PendingChange, records: [PushRecord], pixelSize: PixelSize?) -> Offer? {
        guard let file = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change)?.path else { return nil }
        let refusal = records
            .filter { $0.failures[change.id] != nil }
            .max { $0.date < $1.date }
        guard let refusal, let text = refusal.failures[change.id], isAboutSize(text),
              let sent = refusal.failedChanges.first(where: { $0.id == change.id }),
              PurchaseReviewScreenshotChangeBuilder.screenshot(in: sent)?.path == file
        else { return nil }
        return pixelSize == size ? .copyRefused : .copy(details: text)
    }

    /// The kept file's size in pixels, read from its header.
    static func pixelSize(at path: String) -> PixelSize? {
        guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return PixelSize(width: width, height: height)
    }

    /// “paywall-640x920.png”, from “paywall.png”.
    static func fileName(from name: String) -> String {
        let base = (name as NSString).deletingPathExtension
        return "\(base.isEmpty ? "review-screenshot" : base)-\(size.width)x\(size.height).png"
    }
}
