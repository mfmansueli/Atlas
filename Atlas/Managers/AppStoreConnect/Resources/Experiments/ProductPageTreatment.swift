//
//  ProductPageTreatment.swift
//  Atlas
//

import Foundation

/// One variant of a Product Page Optimization test, e.g. “Outcome”
/// against the current page's “Interface”.
struct ProductPageTreatment: Hashable, Sendable, Identifiable {
    var id: String
    var name: String?
    /// When it was applied to the original page, after the test.
    var promotedDate: Date?

    init(id: String, name: String? = nil, promotedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.promotedDate = promotedDate
    }

    init(_ resource: ScreenshotAPIResource<ProductPageTreatmentAttributes>) {
        self.init(id: resource.id, name: resource.attributes?.name, promotedDate: AppStoreConnectDate.date(resource.attributes?.promotedDate))
    }
}
