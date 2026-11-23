//
//  EncryptionKeyValue.swift
//  Atlas
//

import Foundation

/// What `ITSAppUsesNonExemptEncryption` says in a build: NO (exempt, or no
/// encryption at all) or YES (encryption that needs an approved
/// declaration, named with `ITSEncryptionExportComplianceCode`).
enum EncryptionKeyValue: String, Hashable, Codable, CaseIterable, Sendable {
    // swiftlint:disable:next identifier_name
    case no = "NO"
    case yes = "YES"

    init(usesNonExemptEncryption: Bool) {
        self = usesNonExemptEncryption ? .yes : .no
    }

    /// NO, YES, false, true, 0 or 1, as an assistant may write it.
    init?(text: String) {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "NO", "FALSE", "0": self = .no
        case "YES", "TRUE", "1": self = .yes
        default: return nil
        }
    }

    var usesNonExemptEncryption: Bool { self == .yes }

    /// `<false/>` or `<true/>`, for an Info.plist.
    var plistValue: String { self == .yes ? "<true/>" : "<false/>" }

    /// "exempt" or "not exempt", for the card and refusals.
    var meaning: String {
        self == .yes ? String(localized: "encryption that isn’t exempt") : String(localized: "no encryption that isn’t exempt")
    }
}
