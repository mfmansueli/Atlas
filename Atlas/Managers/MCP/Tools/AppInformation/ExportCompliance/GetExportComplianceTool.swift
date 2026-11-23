//
//  GetExportComplianceTool.swift
//  Atlas
//

import Foundation

/// `get_export_compliance`: an app's Export Compliance as the page shows
/// it: the version and its build, the five answers, the app's encryption
/// declarations, what waits in Review & Push, and what App Store Connect's
/// API takes (the build's `usesNonExemptEncryption`, a new declaration and
/// the build's link to one; not the declaration's documents).
struct GetExportComplianceTool: MCPTool {
    var keys = EncryptionKeyStore.shared
    var projects = EncryptionKeyProjectCenter.shared

    let definition = MCPToolDefinition(
        name: "get_export_compliance",
        title: "Read Export Compliance",
        description: """
        Returns an app's Export Compliance: the version being prepared and the build attached to it (number and \
        usesNonExemptEncryption, as App Store Connect has it and with what's queued on top; null when no build is \
        attached), the answers (usesEncryption, exempt, containsProprietaryCryptography, \
        containsThirdPartyCryptography, availableOnFrenchStore; null where unanswered) and who gave them, the \
        app's encryption declarations (id, state, codeValue, appDescription and their answers), the changes \
        waiting in Review & Push and an open suggestion. App Store Connect's API takes the build's \
        usesNonExemptEncryption, a new encryption declaration and the build's link to one: \
        propose_export_compliance queues them. It doesn't take the declaration's documents, which the person \
        uploads in App Store Connect when Apple asks. answersFromBuild is true when the answers are only what the \
        build's flag implies (false reads as exempt: it can't tell exempt encryption from none). infoPlistKey says \
        whether builds answer the question themselves through ITSAppUsesNonExemptEncryption: state reported \
        (report_encryption_key), readInProject (Atlas read the app target), inferred (the newest uploads arrived \
        answered, which an answer given per build in App Store Connect also does) or unknown; present, value, how \
        Atlas knows, the last report, expected (the value, build settings and Info.plist lines once the answer is \
        settled), canAdd with whyNot, and next: Add It to the Project on the page starts Claude Code to add it, or \
        add it yourself in the project and report it with report_encryption_key.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        ),
        proposalKind: nil
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let state = try await MCPExportComplianceState.load(app, in: context)
        let export = state.export
        let changes = context.workspace.changes.changes(for: app.id, section: .appInformation)
        var result: [String: JSONValue] = [
            "app": ["appId": .string(app.id), "name": .string(app.name)],
            "version": state.content.version.map { ["versionString": .string($0.versionString), "state": .string($0.state.rawValue)] } ?? .null,
            "answers": MCPExportComplianceState.json(state.answers),
            "answeredBy": .string(answeredBy(state)),
            "status": .string(state.answers.status),
            "declarations": .array(export.declarations.map(MCPExportComplianceState.json)),
            "queued": [
                "encryption": MCPExportComplianceState.json(state.queuedEncryption),
                "declaration": MCPExportComplianceState.json(state.queuedDeclaration),
            ],
            "note": .string(Self.note),
            "answersFromBuild": .bool(state.answersAreFromBuild),
        ]
        let builds = await context.workspace.services.appInformation.recentBuilds(for: app)
        result["infoPlistKey"] = state.infoPlistKeyJSON(report: keys.report(for: app.id), project: projects.state(for: app.id), builds: builds)
        result["build"] = export.buildID.map { id in
            [
                "id": .string(id),
                "number": export.buildNumber.map(JSONValue.string) ?? .null,
                "usesNonExemptEncryption": export.usesNonExemptEncryption.map(JSONValue.bool) ?? .null,
                "withQueuedChange": state.builder.usesNonExemptEncryption(export, with: changes).map(JSONValue.bool) ?? .null,
            ]
        } ?? .null
        if let evidence = state.notes.exportEvidence {
            result["openSuggestion"] = [
                "by": .string(evidence.client),
                "summary": .string(evidence.summary),
                "why": .string(evidence.why),
                "evidence": .array(evidence.evidence.map(JSONValue.string)),
            ]
        }
        return .read(.object(result), target: String(localized: "\(app.name) · Export Compliance"))
    }

    /// "person", an assistant's name, "appStoreConnect" (a declaration or
    /// the build's flag) or "nobody".
    private func answeredBy(_ state: MCPExportComplianceState) -> String {
        if state.notes.exportAnswers != nil { return state.notes.exportEvidence?.client ?? "person" }
        if state.export.declaredAnswers != nil || state.export.usesNonExemptEncryption != nil { return "appStoreConnect" }
        return "nobody"
    }

    static let note = """
    Exempt: encryption only through Apple's operating systems (HTTPS and TLS with URLSession or Network, the \
    Keychain, CryptoKit, CommonCrypto, Data Protection), or none at all; the build then answers \
    usesNonExemptEncryption false and needs no declaration. Not exempt: its own or bundled encryption (OpenSSL, \
    BoringSSL, libsodium, WireGuard, a custom protocol, end-to-end encrypted messaging, a VPN), which needs an \
    encryption declaration. The Info.plist key ITSAppUsesNonExemptEncryption (NO when exempt) answers this for \
    every build uploaded after it's added, and ITSEncryptionExportComplianceCode names an approved declaration's \
    codeValue. Answers with no build attached stay in Atlas until the Submit sheet attaches one.
    """
}
