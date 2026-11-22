//
//  ProposeExportComplianceTool.swift
//  Atlas
//

import Foundation

/// `propose_export_compliance`: an assistant's export compliance answers
/// from the project, as the page keeps an assistant's (the answers with
/// their evidence, which the person confirms or rejects there). What App
/// Store Connect takes is queued in Review & Push as the assistant's: the
/// build's `usesNonExemptEncryption`, the same write the page and the
/// Submit sheet send, and for encryption that isn't exempt an encryption
/// declaration (new, or one of the app's with the same answers) linked to
/// the build. With no build attached the answers wait in Atlas, and the
/// Submit sheet sends them with the build it attaches.
struct ProposeExportComplianceTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "usesEncryption": ["type": "boolean", "description": "Whether the app uses, contains or accesses any encryption, HTTPS included."],
        "exempt": ["type": "boolean", "description": "With usesEncryption: only encryption in Apple's operating systems (HTTPS, CryptoKit, CommonCrypto)."],
        "containsProprietaryCryptography": ["type": "boolean", "description": "When not exempt: proprietary or non-standard algorithms."],
        "containsThirdPartyCryptography": ["type": "boolean", "description": "When not exempt: third-party encryption such as OpenSSL or libsodium."],
        "availableOnFrenchStore": ["type": "boolean", "description": "When not exempt: whether the app is on the App Store in France."],
        "appDescription": MCPToolDefinition.string("When not exempt: how the app uses encryption, for a new encryption declaration."),
        "declarationId": MCPToolDefinition.string("When not exempt: one of get_export_compliance's declarations to link the build to instead."),
        "why": MCPToolDefinition.string("Why, in a sentence the person can check."),
        "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. Lumen/Info.plist:42 — ITSAppUsesNonExemptEncryption NO"],
        "could_not_see": MCPToolDefinition.string("What the project can't show, e.g. a server's or an SDK's own encryption."),
        "run": MCPToolDefinition.string("The Suggest Everything run begin_suggestions returned, if this is part of one."),
    ]

    let definition = MCPToolDefinition(
        name: "propose_export_compliance",
        title: "Propose export compliance",
        description: """
        Proposes an app's export compliance answers from the project, with why and evidence (file:line). Send \
        usesEncryption; with it exempt (only encryption in Apple's operating systems: HTTPS and TLS through \
        URLSession or Network, CryptoKit, CommonCrypto, the Keychain); when not exempt, also \
        containsProprietaryCryptography, containsThirdPartyCryptography and availableOnFrenchStore, and \
        appDescription (how the app uses encryption) unless declarationId names one of get_export_compliance's \
        declarations with the same answers. Queued in Review & Push as yours: the build's usesNonExemptEncryption, \
        and when it isn't exempt an encryption declaration linked to the build (an existing one with the same \
        answers is reused). The answers and evidence show on the Export Compliance page, where the person \
        confirms or rejects them. With no build attached the answers wait in Atlas (status "kept") and the \
        Submit sheet sends them. Apple reviews a new declaration and may ask for documents, which the person \
        uploads in App Store Connect. "unchanged" means nothing would change; "refused" says why.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "usesEncryption"]),
        proposalKind: .appInformation
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = String(localized: "\(app.name) · Export Compliance")
        let runID = try arguments.optionalString("run")
        if let stopped = MCPComplianceRunTarget.stoppedRun(runID, context: context) {
            return .refused(stopped.reason, target: target, details: ["code": .string(stopped.code)])
        }
        let state = try await MCPExportComplianceState.load(app, in: context)
        let answers: ExportComplianceAnswers
        switch try Self.answers(arguments) {
        case let .success(parsed): answers = parsed
        case let .failure(refusal): return .refused(refusal.reason, target: target)
        }
        if let mine = [state.queuedEncryption, state.queuedDeclaration].compactMap(\.self).first(where: { !$0.source.isAssistant }) {
            return .refused(String(localized: "The person queued “\(mine.title)” themselves and hasn’t pushed it. Leave Export Compliance to them."), target: target)
        }
        let plan: EncryptionDeclarationPlan?
        switch try declarationPlan(for: answers, arguments: arguments, state: state) {
        case let .success(planned): plan = planned
        case let .failure(refusal): return .refused(refusal.reason, target: target)
        }

        let source = context.source
        let builder = state.builder
        let encryption = builder.encryptionChange(state.export, to: answers, source: source)
        let declaration = plan.flatMap {
            builder.declarationChange($0, export: state.export, source: source, dependsOn: encryption.map(\.id))
        }
        let isUnchanged = answers == state.answers
            && encryption?.requests == state.queuedEncryption?.requests
            && declaration?.requests == state.queuedDeclaration?.requests
        if isUnchanged {
            MCPComplianceRunTarget.noteArrival(of: MCPComplianceRunTarget.encryption, appID: app.id, runID: runID, context: context)
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }

        var notes = state.notes
        notes.exportAnswers = answers
        notes.exportEvidence = try AssistantEvidence(
            client: context.clientName,
            summary: MCPExportComplianceState.summary(of: answers),
            why: arguments.optionalString("why") ?? "",
            evidence: arguments.optionalStrings("evidence") ?? [],
            couldNotSee: arguments.optionalString("could_not_see")
        )
        context.workspace.services.appInformation.notes.setNotes(notes, for: app.id)
        let queue = context.workspace.changes
        for (change, id) in [(encryption, builder.encryptionChangeID), (declaration, builder.declarationChangeID)] {
            if let change { queue.upsert(change) } else { queue.discard(id: id) }
        }
        MCPComplianceRunTarget.noteArrival(of: MCPComplianceRunTarget.encryption, appID: app.id, runID: runID, context: context)
        return MCPToolOutcome(
            result: result(answers: answers, encryption: encryption, declaration: declaration, plan: plan, state: state),
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }

    // MARK: - Answers

    /// The five answers from the arguments, or what's missing.
    private static func answers(_ arguments: MCPToolArguments) throws -> Result<ExportComplianceAnswers, ComplianceAnswerRefusal> {
        guard let uses = try arguments.optionalBool("usesEncryption") else {
            return .failure(ComplianceAnswerRefusal(String(localized: "usesEncryption is true or false.")))
        }
        var answers = ExportComplianceAnswers(answers: [.usesEncryption: uses])
        guard uses else { return .success(answers) }
        guard let exempt = try arguments.optionalBool("exempt") else {
            return .failure(ComplianceAnswerRefusal(String(localized: "With usesEncryption true, say whether it's exempt: exempt true or false.")))
        }
        answers[.isExempt] = exempt
        let questions: [(String, ExportComplianceQuestion)] = [
            ("containsProprietaryCryptography", .proprietary),
            ("containsThirdPartyCryptography", .thirdParty),
            ("availableOnFrenchStore", .availableInFrance),
        ]
        var missing: [String] = []
        for (name, question) in questions {
            if let value = try arguments.optionalBool(name) { answers[question] = value } else { missing.append(name) }
        }
        guard exempt || missing.isEmpty else {
            return .failure(ComplianceAnswerRefusal(String(localized: "Encryption that isn't exempt needs \(missing.formatted(.list(type: .and))).")))
        }
        return .success(answers)
    }

    /// The declaration encryption that isn't exempt gets: the one named,
    /// else one with the same answers, else a new one with appDescription.
    private func declarationPlan(
        for answers: ExportComplianceAnswers,
        arguments: MCPToolArguments,
        state: MCPExportComplianceState
    ) throws -> Result<EncryptionDeclarationPlan?, ComplianceAnswerRefusal> {
        guard answers.usesNonExemptEncryption == true else { return .success(nil) }
        let declarations = state.export.declarations
        if let id = try arguments.optionalString("declarationId") {
            guard let named = declarations.first(where: { $0.id == id }) else {
                let known = declarations.map(\.id)
                let list = known.isEmpty ? String(localized: "It has none.") : String(localized: "They are \(known.formatted(.list(type: .and))).")
                return .failure(ComplianceAnswerRefusal(String(localized: "\(state.app.name) has no encryption declaration “\(id)”. \(list)")))
            }
            guard named.isUsable else {
                return .failure(ComplianceAnswerRefusal(String(localized: "Declaration “\(id)” is \(named.summary.lowercased()): a build can't use it. Send appDescription for a new one.")))
            }
            guard named.matches(answers) else {
                return .failure(ComplianceAnswerRefusal(String(localized: "Declaration “\(id)” was made with other answers. Send appDescription for a new one.")))
            }
            return .success(.link(named))
        }
        guard let plan = try EncryptionDeclarationPlan.plan(
            for: answers,
            appDescription: arguments.optionalString("appDescription"),
            declarations: declarations
        ) else {
            return .failure(ComplianceAnswerRefusal(String(localized: """
            Encryption that isn't exempt needs an encryption declaration: send appDescription (how the app uses \
            encryption), or declarationId for one of the app's declarations with the same answers.
            """)))
        }
        return .success(plan)
    }

    // MARK: - Result

    private func result(
        answers: ExportComplianceAnswers,
        encryption: PendingChange?,
        declaration: PendingChange?,
        plan: EncryptionDeclarationPlan?,
        state: MCPExportComplianceState
    ) -> JSONValue {
        let queued = [encryption, declaration].compactMap(\.self)
        var result: [String: JSONValue] = [
            "status": queued.isEmpty ? "kept" : "queued",
            "answers": MCPExportComplianceState.json(answers),
            "usesNonExemptEncryption": answers.usesNonExemptEncryption.map(JSONValue.bool) ?? .null,
            "changeIds": .array(queued.map { .string($0.id) }),
        ]
        switch plan {
        case let .create(description, _)?:
            result["declaration"] = ["action": "create", "appDescription": .string(description), "linksBuild": .bool(state.export.buildID != nil)]
        case let .link(existing)?:
            result["declaration"] = [
                "action": "link", "declarationId": .string(existing.id), "state": existing.state.map(JSONValue.string) ?? .null,
                "codeValue": existing.codeValue.map(JSONValue.string) ?? .null, "linksBuild": .bool(state.export.buildID != nil),
            ]
        case nil:
            result["declaration"] = .null
        }
        result["note"] = .string(note(queued: !queued.isEmpty, plan: plan, state: state))
        return .object(result)
    }

    private func note(queued: Bool, plan: EncryptionDeclarationPlan?, state: MCPExportComplianceState) -> String {
        let waiting = """
        Waiting in Review & Push as yours until the person pushes; the answers and your evidence show on the Export \
        Compliance page, where they confirm or reject them.
        """
        let kept = """
        Kept in Atlas on the Export Compliance page: the build already says this, or no build is attached yet (the \
        Submit sheet sends it with the build it attaches).
        """
        var parts = [queued ? waiting : kept]
        if state.export.buildID == nil, case let .link(existing)? = plan {
            parts.append("With no build attached, link declaration \(existing.id) in App Store Connect, or name its code in the Info.plist (ITSEncryptionExportComplianceCode).")
        }
        if case .create? = plan {
            parts.append("Apple reviews the new declaration and may ask for documents, which the person uploads in App Store Connect.")
        }
        parts.append("Add ITSAppUsesNonExemptEncryption to the Info.plist (NO when exempt) so App Store Connect stops asking for each build.")
        return parts.joined(separator: " ")
    }
}
