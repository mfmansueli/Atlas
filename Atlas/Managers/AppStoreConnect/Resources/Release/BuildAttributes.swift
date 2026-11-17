//
//  BuildAttributes.swift
//  Atlas
//

import Foundation

/// A `builds` resource, as Submit for Review lists it.
struct BuildAttributes: Decodable, Sendable {
    /// The build number, e.g. "212".
    var version: String?
    var uploadedDate: String?
    /// `PROCESSING`, `FAILED`, `INVALID` or `VALID`.
    var processingState: String?
    var expired: Bool?
    var usesNonExemptEncryption: Bool?
}
