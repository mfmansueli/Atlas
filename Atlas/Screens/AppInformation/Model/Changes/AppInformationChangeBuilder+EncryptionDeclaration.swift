//
//  AppInformationChangeBuilder+EncryptionDeclaration.swift
//  Atlas
//

import Foundation

// Export Compliance's encryption declaration, for encryption that isn't
// exempt: one change that creates the declaration (`POST
// /v1/appEncryptionDeclarations`) and links the version's build to it
// (`PATCH /v1/builds/{id}`, its `appEncryptionDeclaration` filled in with
// the created id), or only links the build to a declaration the app
// already has. App Store Connect can't delete a declaration, so nothing is
// restored. Its documents, when Apple asks for them, are uploaded in App
// Store Connect.
extension AppInformationChangeBuilder {
    static let encryptionDeclarationKey = "declaration"
    static let encryptionDeclarationType = "appEncryptionDeclarations"

    var declarationChangeID: String { versionChangeID(.exportCompliance, Self.encryptionDeclarationKey) }

    /// The declaration change for `plan`; nil when it links a build and
    /// there's none. `dependsOn` is the build's encryption change when one
    /// is queued with it, so discarding that discards this too.
    func declarationChange(
        _ plan: EncryptionDeclarationPlan,
        export: ExportComplianceValues,
        source: ChangeSource = .you,
        dependsOn: PendingChange.ID? = nil
    ) -> PendingChange? {
        let link = { (declarationID: String) in
            export.buildID.map { buildID in
                Self.patch("builds", id: buildID, relationships: [
                    "appEncryptionDeclaration": AppInformationWriteDocument.Relationship(
                        data: AppInformationWriteDocument.Identifier(type: Self.encryptionDeclarationType, id: declarationID)
                    ),
                ])
            }
        }
        let title = export.buildNumber.map { String(localized: "Encryption declaration · build \($0)") }
            ?? String(localized: "Encryption declaration")
        var change: PendingChange
        switch plan {
        case let .create(description, answers):
            let create = AppInformationWriteDocument.create(
                type: Self.encryptionDeclarationType,
                attributes: [
                    "appDescription": .string(description),
                    "containsProprietaryCryptography": .bool(answers[.proprietary] ?? false),
                    "containsThirdPartyCryptography": .bool(answers[.thirdParty] ?? false),
                    "availableOnFrenchStore": .bool(answers[.availableInFrance] ?? false),
                ],
                parent: "app",
                parentType: "apps",
                parentID: appID
            )
            let post = PushRequest(method: .post, path: "/v1/\(Self.encryptionDeclarationType)", body: create.encoded())
            let linked = link(PushRequest.createdIDPlaceholder(type: Self.encryptionDeclarationType))
            change = PendingChange(
                id: declarationChangeID,
                appID: appID,
                section: .appInformation,
                group: group(.exportCompliance),
                title: title,
                oldValue: String(localized: "None"),
                newValue: String(localized: "New declaration"),
                source: source,
                requests: [post] + [linked].compactMap(\.self)
            )
            change.creation = PendingCreation(
                id: declarationChangeID,
                title: String(localized: "Create an encryption declaration"),
                detail: linked == nil
                    ? String(localized: """
                    Apple reviews it and may ask for documents in App Store Connect. No build is attached yet: link it there, \
                    or name its code in the Info.plist (ITSEncryptionExportComplianceCode) once it’s approved.
                    """)
                    : String(localized: "Apple reviews it and may ask for documents in App Store Connect. The build is linked to it in the same push."),
                source: source,
                fields: Self.declarationFields(description: description, answers: answers, source: source)
            )
        case let .link(declaration):
            guard let request = link(declaration.id) else { return nil }
            change = PendingChange(
                id: declarationChangeID,
                appID: appID,
                section: .appInformation,
                group: group(.exportCompliance),
                title: title,
                oldValue: String(localized: "None"),
                newValue: String(localized: "Existing declaration · \(declaration.summary)"),
                source: source,
                requests: [request]
            )
        }
        change.dependsOn = dependsOn
        return change
    }

    /// What the declaration says, for Review & Push.
    private static func declarationFields(description: String, answers: ExportComplianceAnswers, source: ChangeSource) -> [PendingChangePart] {
        let answer = { (question: ExportComplianceQuestion) in answers[question] == true ? String(localized: "Yes") : String(localized: "No") }
        let part = { (id: String, title: String, value: String) in
            PendingChangePart(id: id, title: title, oldValue: "", newValue: value, source: source)
        }
        return [
            part("appDescription", String(localized: "How the app uses encryption"), description),
            part("proprietary", ExportComplianceQuestion.proprietary.title, answer(.proprietary)),
            part("thirdParty", ExportComplianceQuestion.thirdParty.title, answer(.thirdParty)),
            part("availableInFrance", ExportComplianceQuestion.availableInFrance.title, answer(.availableInFrance)),
        ]
    }
}
