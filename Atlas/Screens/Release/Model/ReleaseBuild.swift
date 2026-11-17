//
//  ReleaseBuild.swift
//  Atlas
//

import Foundation

/// A build uploaded for the version, from Xcode or Xcode Cloud.
struct ReleaseBuild: Identifiable, Hashable, Sendable {
    enum Processing: String, Hashable, Sendable {
        case processing = "PROCESSING"
        case valid = "VALID"
        case failed = "FAILED"
        case invalid = "INVALID"
    }

    var id: String
    /// The build number, e.g. "212".
    var number: String
    var uploaded: Date?
    var processing: Processing
    var isExpired = false
    /// The encryption answer the build carries (from its Info.plist or an
    /// earlier answer); nil when nobody answered.
    var usesNonExemptEncryption: Bool?

    /// Processed by Apple and still valid: it can go to App Review.
    var isSelectable: Bool { processing == .valid && !isExpired }

    /// "1.4 (212)".
    func title(version: String) -> String {
        "\(version) (\(number))"
    }

    /// "Uploaded Nov 15", or why it can't be chosen.
    var detail: String {
        if isExpired { return String(localized: "Expired") }
        switch processing {
        case .processing:
            return String(localized: "Apple is still processing it")
        case .failed, .invalid:
            return String(localized: "Apple couldn’t process it")
        case .valid:
            guard let uploaded else { return String(localized: "Ready") }
            return String(localized: "Uploaded \(uploaded.formatted(.dateTime.month(.abbreviated).day()))")
        }
    }
}
