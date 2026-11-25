//
//  SkeletonTokensTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Rule zero: the skeletons' sizes in `Metrics` are the ones
/// `design-tokens.json → skeleton` holds.
@Suite("Skeleton tokens")
struct SkeletonTokensTests {
    private let skeleton: [String: Any]

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "design-tokens", withExtension: "json"), "design-tokens.json is in the app")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let tokens = try #require(object as? [String: Any])
        skeleton = try #require(tokens["skeleton"] as? [String: Any], "design-tokens.json has a skeleton group")
    }

    private static let metrics: [String: CGFloat] = [
        "line": Metrics.skeletonLine,
        "captionLine": Metrics.skeletonCaptionLine,
        "bodyLine": Metrics.skeletonBodyLine,
        "titleLine": Metrics.skeletonTitleLine,
        "listRowHeight": Metrics.skeletonListRowHeight,
        "icon": Metrics.skeletonIcon,
        "cardHeight": Metrics.skeletonCardHeight,
        "cellWidth": Metrics.skeletonCellWidth,
        "nameWidth": Metrics.skeletonNameWidth,
        "flagWidth": Metrics.skeletonFlagWidth,
        "flagHeight": Metrics.skeletonFlagHeight,
        "tileWidth": Metrics.skeletonTileWidth,
        "tileAspect": Metrics.skeletonTileAspect,
        "overviewTitle": Metrics.skeletonOverviewTitle,
        "overviewTitleWidth": Metrics.skeletonOverviewTitleWidth,
        "overviewCardHeight": Metrics.skeletonOverviewCardHeight,
        "storePageRowHeight": Metrics.skeletonStorePageRowHeight,
        "storePageCellWidth": Metrics.skeletonStorePageCellWidth,
        "handTileWidth": Metrics.skeletonHandTileWidth,
        "eventCardHeight": Metrics.skeletonEventCardHeight,
        "rowCardHeight": Metrics.skeletonRowCardHeight,
        "reviewsSideHeight": Metrics.skeletonReviewsSideHeight,
        "urlCellWidth": Metrics.skeletonURLCellWidth,
        "funnelStageHeight": Metrics.skeletonFunnelStageHeight,
        "analyticsCardWidth": Metrics.skeletonAnalyticsCardWidth,
        "buildRowHeight": Metrics.skeletonBuildRowHeight,
        "assetRowHeight": Metrics.skeletonAssetRowHeight,
        "assetThumbnailWidth": Metrics.skeletonAssetThumbnailWidth,
        "assetThumbnailHeight": Metrics.skeletonAssetThumbnailHeight,
        "planRowHeight": Metrics.skeletonPlanRowHeight,
    ]

    @Test func everySizeMatchesTheJSON() throws {
        let names = Set(skeleton.keys.filter { !$0.hasPrefix("$") })
        #expect(names == Set(Self.metrics.keys), "the JSON names every skeleton metric, and only those")
        for (name, value) in Self.metrics {
            let number = try #require(skeleton[name] as? NSNumber, "\(name)")
            #expect(abs(CGFloat(number.doubleValue) - value) < 0.001, "\(name): \(value) in Metrics, \(number) in the JSON")
        }
    }

    /// Nothing under the 10 pt floor's spirit: a text line stands for real
    /// text, a tile for a real screenshot.
    @Test func linesAreShorterThanTheirRows() {
        #expect(Metrics.skeletonLine < Metrics.tableRowHeight)
        #expect(Metrics.skeletonTitleLine < Metrics.skeletonListRowHeight)
        #expect(Metrics.skeletonIcon < Metrics.skeletonListRowHeight)
        #expect(Metrics.skeletonCaptionLine < Metrics.skeletonLine)
    }
}
