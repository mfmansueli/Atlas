//
//  Metrics+StoreArtwork.swift
//  Atlas
//

import CoreGraphics

/// Board 78's header and search artwork on the Screenshots page and in the
/// On the App Store preview.
extension Metrics {
    /// The header (21:9) and search (3:2) tiles at the top of Screenshots:
    /// side by side, the same height.
    static let storeArtworkTileHeight: CGFloat = 154
    static let storeArtworkHeaderWidth: CGFloat = 360
    static let storeArtworkSearchWidth: CGFloat = 231
    /// A screenshot in the search tile when there's no search artwork.
    static let storeArtworkFallbackShotWidth: CGFloat = 62
    /// All Languages' small header and search beside each language.
    static let storeArtworkMiniHeight: CGFloat = 47
    static let storeArtworkMiniHeaderWidth: CGFloat = 110
    static let storeArtworkMiniSearchWidth: CGFloat = 70
    /// Under this page width the On the App Store preview leaves the
    /// Screenshots page.
    static let storeArtworkPreviewMinPageWidth: CGFloat = 900
    /// The On the App Store column beside a page.
    static let storePreviewColumnWidth: CGFloat = 290
    /// The grey page standing in until the store texts are read.
    static let storePreviewSkeletonHeight: CGFloat = 460
    /// The header at the top of the App Store preview: the centre of the
    /// 21:9, as an iPhone shows it.
    static let storePreviewHeaderHeight: CGFloat = 150
    /// The icon in the preview's "In search results" card.
    static let storePreviewSearchIcon: CGFloat = 40
    /// The search artwork in that card, and a screenshot there without it.
    static let storePreviewSearchArtWidth: CGFloat = 264
    static let storePreviewSearchShotWidth: CGFloat = 80
}
