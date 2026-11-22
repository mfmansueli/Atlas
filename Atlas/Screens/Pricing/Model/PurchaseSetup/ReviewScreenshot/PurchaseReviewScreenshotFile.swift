//
//  PurchaseReviewScreenshotFile.swift
//  Atlas
//

import Foundation

/// The App Review screenshot of a subscription or in-app purchase (the
/// paywall, usually), kept on this Mac (`PurchaseReviewScreenshotFolder`)
/// until the push uploads these exact bytes.
struct PurchaseReviewScreenshotFile: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// The name it had, and the name App Store Connect gets.
    var fileName: String
    /// The bytes' MD5, as App Store Connect reports it back in
    /// `sourceFileChecksum`: that's how a push that stopped knows it's up.
    var checksum: String
    var pixelSize: PixelSize
    var byteCount: Int

    /// `png` or `jpg`: the extension the kept copy has.
    var pathExtension: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext == "jpeg" || ext == "jpg" ? "jpg" : "png"
    }

    /// "paywall.png · 1290 × 2796".
    var summary: String {
        "\(fileName) · \(pixelSize.width) × \(pixelSize.height)"
    }

    /// The smallest side App Review reads comfortably. Apple's help asks
    /// for a screenshot of the purchase as it shows in the app; a thumbnail
    /// is refused before it's queued.
    static let minimumSide = 320
}
