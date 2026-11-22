//
//  EncryptionDeclarationPlan.swift
//  Atlas
//

import Foundation

/// What a build whose encryption isn't exempt gets in App Store Connect:
/// a new encryption declaration (`POST /v1/appEncryptionDeclarations`, with
/// the three questions it asks and how the app uses encryption), or one of
/// the app's declarations that has the same answers. Either way the build
/// shown is linked to it (`PATCH /v1/builds/{id}` with its
/// `appEncryptionDeclaration`) when the version has one. Apple reviews a
/// new declaration and may ask for documents, which the person uploads in
/// App Store Connect.
enum EncryptionDeclarationPlan: Hashable, Sendable {
    case create(appDescription: String, answers: ExportComplianceAnswers)
    case link(ExportEncryptionDeclaration)

    /// The plan for `answers`: nil when the encryption is exempt (or not
    /// answered), else an existing usable declaration with the same answers
    /// (an approved one first), else a new one with `appDescription`. Nil
    /// too when a new one is needed and there's no description.
    static func plan(
        for answers: ExportComplianceAnswers,
        appDescription: String?,
        declarations: [ExportEncryptionDeclaration]
    ) -> EncryptionDeclarationPlan? {
        guard answers.usesNonExemptEncryption == true else { return nil }
        let usable = declarations.filter { $0.isUsable && $0.matches(answers) }
        if let existing = usable.first(where: \.isApproved) ?? usable.first {
            return .link(existing)
        }
        let description = appDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !description.isEmpty else { return nil }
        return .create(appDescription: description, answers: answers)
    }
}
