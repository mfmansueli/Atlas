//
//  ReviewBulkProgress.swift
//  Atlas
//

import Foundation

/// Reply to All while it sends.
struct ReviewBulkProgress: Hashable, Sendable {
    var sent: Int
    var total: Int
}
