//
//  MCPExportComplianceState.swift
//  Atlas
//

import Foundation

/// An app's Export Compliance as the tools see it, the same as the page:
/// the version shown and its build, the answers (the ones kept in Atlas,
/// else the newest declaration's, else what the build's flag implies), the
/// app's encryption declarations, and the changes waiting in Review & Push.
@MainActor
struct MCPExportComplianceState {
    let app: StoreApp
    let content: AppInformationContent
    let builder: AppInformationChangeBuilder
    let notes: AppInformationNotes
    /// The build's encryption change, if one waits in Review & Push.
    let queuedEncryption: PendingChange?
    /// The encryption declaration change, if one waits.
    let queuedDeclaration: PendingChange?

    var export: ExportComplianceValues { content.export }

    /// As the page shows them.
    var answers: ExportComplianceAnswers {
        notes.exportAnswers ?? export.declaredAnswers ?? ExportComplianceAnswers(usesNonExemptEncryption: export.usesNonExemptEncryption)
    }

    /// The answers are only what the build's flag implies: nobody answered
    /// them, and no declaration has them.
    var answersAreFromBuild: Bool {
        notes.exportAnswers == nil && export.declaredAnswers == nil && export.usesNonExemptEncryption != nil
    }

    static func load(_ app: StoreApp, in context: MCPToolContext) async throws -> MCPExportComplianceState {
        let services = context.workspace.services.appInformation
        let content = try await services.content(for: app, versionID: nil)
        let builder = AppInformationChangeBuilder(appID: app.id, ids: content.ids, versionString: content.version?.versionString)
        let queue = context.workspace.changes
        return MCPExportComplianceState(
            app: app,
            content: content,
            builder: builder,
            notes: services.notes.notes(for: app.id),
            queuedEncryption: queue.change(id: builder.encryptionChangeID),
            queuedDeclaration: queue.change(id: builder.declarationChangeID)
        )
    }

    // MARK: - JSON

    /// `{usesEncryption, exempt, containsProprietaryCryptography,
    /// containsThirdPartyCryptography, availableOnFrenchStore}`, null where
    /// unanswered: the API's names.
    static func json(_ answers: ExportComplianceAnswers) -> JSONValue {
        let value = { (question: ExportComplianceQuestion) in answers[question].map(JSONValue.bool) ?? .null }
        return [
            "usesEncryption": value(.usesEncryption),
            "exempt": value(.isExempt),
            "containsProprietaryCryptography": value(.proprietary),
            "containsThirdPartyCryptography": value(.thirdParty),
            "availableOnFrenchStore": value(.availableInFrance),
        ]
    }

    static func json(_ declaration: ExportEncryptionDeclaration) -> JSONValue {
        let answers = declaration.answers
        let value = { (question: ExportComplianceQuestion) in answers[question].map(JSONValue.bool) ?? .null }
        return [
            "id": .string(declaration.id),
            "state": declaration.state.map(JSONValue.string) ?? .null,
            "codeValue": declaration.codeValue.map(JSONValue.string) ?? .null,
            "createdDate": declaration.createdDate.map(JSONValue.string) ?? .null,
            "appDescription": declaration.appDescription.map(JSONValue.string) ?? .null,
            "containsProprietaryCryptography": value(.proprietary),
            "containsThirdPartyCryptography": value(.thirdParty),
            "availableOnFrenchStore": value(.availableInFrance),
        ]
    }

    /// `{changeId, value, by}` of a queued change, or null.
    static func json(_ change: PendingChange?) -> JSONValue {
        guard let change else { return .null }
        return ["changeId": .string(change.id), "title": .string(change.title), "value": .string(change.newValue), "by": .string(change.source.title)]
    }

    /// "Uses encryption: Yes · exempt: Yes", the line the page's evidence
    /// shows.
    static func summary(of answers: ExportComplianceAnswers) -> String {
        let answer = { (flag: Bool) in flag ? String(localized: "Yes") : String(localized: "No") }
        let parts: [(ExportComplianceQuestion, String)] = [
            (.usesEncryption, String(localized: "Uses encryption")),
            (.isExempt, String(localized: "exempt")),
            (.proprietary, String(localized: "proprietary")),
            (.thirdParty, String(localized: "third-party")),
            (.availableInFrance, String(localized: "France")),
        ]
        return parts.compactMap { question, name in answers[question].map { "\(name): \(answer($0))" } }.joined(separator: " · ")
    }
}
