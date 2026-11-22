//
//  ScreenshotHandTestFiles.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// Files for the Screenshots by hand tests.
enum ScreenshotHandTestFiles {
    static func file(_ id: String, checksum: String? = nil, size: PixelSize = PixelSize(width: 1320, height: 2868)) -> ScreenshotHandFile {
        ScreenshotHandFile(
            id: id, fileName: "\(id).png", checksum: checksum ?? "sum-\(id)", pixelSize: size, byteCount: 1000, copiedFrom: nil, proposedBy: nil,
            addedAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func chosen(_ name: String, size: PixelSize = PixelSize(width: 1320, height: 2868)) -> ScreenshotHandChosenFile {
        ScreenshotHandChosenFile(fileName: name, data: ScreenshotsHandDebugFiles.png(size, red: 0.2, green: 0.4, blue: 0.6))
    }

    static func templateSet(_ locale: String = "ja", count: Int = 5) -> ScreenshotHandSet {
        .starting(locale: locale, displayType: .iPhone, bases: (0..<count).map { .template(slot: $0) })
    }
}
#endif
