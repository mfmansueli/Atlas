//
//  EncryptionKeyAnswer.swift
//  Atlas
//

import Foundation

/// What the export compliance key should say once the answer is settled:
/// NO, or YES with an approved declaration's code, and what settled it.
struct EncryptionKeyAnswer: Hashable, Sendable {
    enum Basis: Hashable, Sendable {
        /// The person answered or confirmed the answers in Atlas.
        case confirmed
        /// Only the build's `usesNonExemptEncryption` says it, and nothing
        /// in Atlas or App Store Connect contradicts it.
        case build(number: String?)
    }

    var value: EncryptionKeyValue
    /// The approved declaration's `codeValue`, with YES.
    var code: String?
    /// That declaration's id.
    var declarationID: String?
    var basis: Basis

    static let key = "ITSAppUsesNonExemptEncryption"
    static let codeKey = "ITSEncryptionExportComplianceCode"

    /// What goes in an Info.plist.
    var snippet: String {
        Self.snippet(value: value, code: code)
    }

    static func snippet(value: EncryptionKeyValue, code: String?) -> String {
        var lines = ["<key>\(key)</key>", value.plistValue]
        if value == .yes {
            lines += ["<key>\(codeKey)</key>", "<string>\(code ?? "CODE")</string>"]
        }
        return lines.joined(separator: "\n")
    }

    /// The build settings for a target that generates its Info.plist
    /// (`GENERATE_INFOPLIST_FILE = YES`).
    var buildSettings: [String] {
        var settings = ["INFOPLIST_KEY_\(Self.key) = \(value.rawValue)"]
        if value == .yes, let code { settings.append("INFOPLIST_KEY_\(Self.codeKey) = \(code)") }
        return settings
    }

    /// "the answers you confirmed", "build 42's answer".
    var basisText: String {
        switch basis {
        case .confirmed: String(localized: "the answers confirmed on the Export Compliance page")
        case let .build(number?): String(localized: "build \(number)’s answer in App Store Connect")
        case .build(nil): String(localized: "the build’s answer in App Store Connect")
        }
    }
}
