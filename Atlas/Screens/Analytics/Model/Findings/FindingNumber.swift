//
//  FindingNumber.swift
//  Atlas
//

import Foundation

/// One number behind a finding: "Downloads per page view · 17.6% · U.S. 33.0%".
struct FindingNumber: Hashable, Sendable, Codable {
    var label: String
    var value: String
    var note: String?
}
