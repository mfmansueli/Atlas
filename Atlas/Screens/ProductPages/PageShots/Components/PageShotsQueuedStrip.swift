//
//  PageShotsQueuedStrip.swift
//  Atlas
//

import SwiftUI

/// The page's own screenshots waiting in Review & Push, from the PNGs
/// Make Screenshots for This Page laid out, left to right in every
/// language.
struct PageShotsQueuedStrip: View {
    let files: [ProductPageScreenshotsPush.File]
    let device: ProductPageDevice
    let height: CGFloat
    /// The App Store preview shows the first three.
    var limit: Int?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xSmall) {
                ForEach(Array(files.prefix(limit ?? files.count).enumerated()), id: \.offset) { index, file in
                    PageShotsTile(
                        url: URL(fileURLWithPath: file.path), aspect: PageShotsTile.aspect(device == .iPad ? .iPad : .iPhone),
                        height: height, label: String(localized: "Screenshot \(index + 1), in Review & Push")
                    )
                }
            }
        }
        .scrollIndicators(.automatic)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.screenshots.queued")
    }
}
