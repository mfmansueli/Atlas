//
//  AnalyticsReportSegmentAttributes.swift
//  Atlas
//

import Foundation

/// `analyticsReportSegments`: one gzip file of an instance, at a signed URL
/// that works for five minutes.
struct AnalyticsReportSegmentAttributes: Decodable, Hashable, Sendable {
    var url: URL?
    var checksum: String?
    var sizeInBytes: Int?
}
