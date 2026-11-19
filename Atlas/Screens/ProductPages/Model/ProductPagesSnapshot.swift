//
//  ProductPagesSnapshot.swift
//  Atlas
//

import Foundation

/// What Atlas read for Product Pages: the custom pages, and the default
/// page they're compared with and start from.
struct ProductPagesSnapshot: Codable, Hashable, Sendable {
    /// Apple allows this many custom product pages for each app; hidden,
    /// rejected and draft pages count.
    static let limit = 70

    var pages: [ProductPage]
    var defaultPage: ProductPageDefault
    /// When it was read, for the offline banner.
    var readAt: Date = .now
}
