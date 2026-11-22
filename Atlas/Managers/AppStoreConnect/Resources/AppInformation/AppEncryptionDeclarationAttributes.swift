//
//  AppEncryptionDeclarationAttributes.swift
//  Atlas
//

import Foundation

/// The `appEncryptionDeclarations` attributes: the export compliance
/// answers of a declaration, its description, Apple's review state and,
/// once approved, the code a build's Info.plist names
/// (`ITSEncryptionExportComplianceCode`). Atlas reads them to start from
/// and to link a build to one; it creates a declaration (`POST`) when an
/// app's encryption isn't exempt, but never uploads its documents.
struct AppEncryptionDeclarationAttributes: Decodable, Sendable {
    var usesEncryption: Bool?
    var exempt: Bool?
    var containsProprietaryCryptography: Bool?
    var containsThirdPartyCryptography: Bool?
    var availableOnFrenchStore: Bool?
    /// ISO 8601; the newest declaration is the one that applies.
    var createdDate: String?
    var appDescription: String?
    /// `CREATED`, `IN_REVIEW`, `APPROVED`, `REJECTED`, `INVALID` or `EXPIRED`.
    var appEncryptionDeclarationState: String?
    var codeValue: String?
}
