//
//  NominationAttributes.swift
//  Atlas
//

import Foundation

/// A nomination's attributes as `GET /v1/nominations` returns them (App
/// Store Connect API 4.6.1). Everything is optional: Apple leaves out what a
/// draft doesn't have yet.
struct NominationAttributes: Decodable, Sendable {
    var name: String?
    /// `APP_LAUNCH`, `APP_ENHANCEMENTS` or `NEW_CONTENT`.
    var type: String?
    var description: String?
    var createdDate: String?
    var lastModifiedDate: String?
    var submittedDate: String?
    /// `DRAFT`, `SUBMITTED` or `ARCHIVED`.
    var state: String?
    var publishStartDate: String?
    var publishEndDate: String?
    /// `IPHONE`, `IPAD`, `APPLE_TV`, `APPLE_WATCH`, `MAC`, `VISION`.
    var deviceFamilies: [String]?
    var locales: [String]?
    var supplementalMaterialsUris: [String]?
    var hasInAppEvents: Bool?
    var launchInSelectMarketsFirst: Bool?
    var notes: String?
    var preOrderEnabled: Bool?
}
