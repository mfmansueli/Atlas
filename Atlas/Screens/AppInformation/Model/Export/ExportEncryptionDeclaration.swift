//
//  ExportEncryptionDeclaration.swift
//  Atlas
//

import Foundation

/// One of the app's encryption declarations in App Store Connect: the
/// answers it was made with, Apple's review state and, once approved, the
/// code a build's Info.plist can name so App Store Connect links the build
/// to it (`ITSEncryptionExportComplianceCode`).
struct ExportEncryptionDeclaration: Identifiable, Hashable, Sendable {
    var id: String
    /// `CREATED`, `IN_REVIEW`, `APPROVED`, `REJECTED`, `INVALID` or
    /// `EXPIRED`; nil when App Store Connect didn't say.
    var state: String?
    var codeValue: String?
    /// ISO 8601.
    var createdDate: String?
    var appDescription: String?
    var answers: ExportComplianceAnswers

    static let approvedState = "APPROVED"

    /// Apple rejected it or it no longer applies: a build can't use it.
    var isUsable: Bool {
        !["REJECTED", "INVALID", "EXPIRED"].contains(state ?? "")
    }

    var isApproved: Bool { state == Self.approvedState }

    /// Made with the same answers to the three questions a declaration
    /// asks: proprietary and third-party cryptography, and France.
    func matches(_ other: ExportComplianceAnswers) -> Bool {
        [ExportComplianceQuestion.proprietary, .thirdParty, .availableInFrance].allSatisfy { answers[$0] == other[$0] }
    }

    /// "Approved · code a1b2c3", "In review", for Review & Push.
    var summary: String {
        let name = switch state {
        case "APPROVED"?: String(localized: "Approved")
        case "IN_REVIEW"?: String(localized: "In review")
        case "CREATED"?: String(localized: "Created")
        case "REJECTED"?: String(localized: "Rejected")
        case "INVALID"?: String(localized: "Invalid")
        case "EXPIRED"?: String(localized: "Expired")
        default: String(localized: "Declared")
        }
        guard let codeValue, !codeValue.isEmpty else { return name }
        return String(localized: "\(name) · code \(codeValue)")
    }
}
