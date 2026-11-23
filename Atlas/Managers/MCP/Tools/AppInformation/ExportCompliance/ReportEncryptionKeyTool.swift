//
//  ReportEncryptionKeyTool.swift
//  Atlas
//

import Foundation

/// `report_encryption_key`: what an assistant did about the export
/// compliance key (`ITSAppUsesNonExemptEncryption`) in the app's project:
/// added it, found it there, or couldn't. Nothing reaches App Store
/// Connect. Kept per app, replacing the last: Export Compliance's card
/// shows it ("Added in project.pbxproj (Lumen) — builds uploaded from now
/// on answer it"), and `get_export_compliance`'s infoPlistKey returns it. A
/// value that contradicts the answer settled in Atlas is refused.
struct ReportEncryptionKeyTool: MCPTool {
    var store = EncryptionKeyStore.shared
    var now: @Sendable () -> Date = { .now }

    private static let place: JSONValue = [
        "type": "object",
        "properties": [
            "file": MCPToolDefinition.string("The file changed or read, from the project folder, e.g. Lumen.xcodeproj/project.pbxproj."),
            "line": ["type": "integer", "description": "The line of the key in an Info.plist."],
            "buildSetting": MCPToolDefinition.string("The build setting, e.g. INFOPLIST_KEY_ITSAppUsesNonExemptEncryption."),
            "target": MCPToolDefinition.string("The target, e.g. Lumen."),
            "configurations": ["type": "array", "items": ["type": "string"], "description": "e.g. Debug, Release."],
        ],
        "required": ["file", "target"],
    ]

    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "status": ["type": "string", "enum": ["added", "alreadyThere", "couldNotAdd"], "description": "What you did."],
        "value": ["type": "string", "enum": ["NO", "YES"], "description": "What ITSAppUsesNonExemptEncryption says now."],
        "complianceCode": MCPToolDefinition.string("With YES: ITSEncryptionExportComplianceCode, the approved declaration's codeValue."),
        "where": ["type": "array", "items": place, "description": "Each place the key is set; at least one unless couldNotAdd."],
        "commit": MCPToolDefinition.string("The commit you made, when the project's instructions say changes are committed."),
        "reason": MCPToolDefinition.string("With couldNotAdd: why, in a sentence the person can act on."),
        "notes": MCPToolDefinition.string("Anything else the person should know, e.g. what the key said before."),
    ]

    let definition = MCPToolDefinition(
        name: "report_encryption_key",
        title: "Report the export compliance key",
        description: """
        After adding the export compliance key to the app's project (or finding it there), tell Atlas: status added \
        (you changed the project), alreadyThere (it already had the key with this value) or couldNotAdd (with reason); \
        value NO or YES (ITSAppUsesNonExemptEncryption; YES also needs complianceCode, the approved declaration's \
        codeValue); where, each place it's set (file with line, or buildSetting, the target and its configurations: \
        the app target, and an embedded app with its own bundle such as a watchOS app); commit when you made one; \
        notes. get_export_compliance's infoPlistKey.expected says the value once the answer is settled; a value that \
        contradicts it is refused. Each report replaces the last; the Export Compliance page shows it. Nothing reaches \
        App Store Connect: builds uploaded from then on answer the question themselves.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "status"]),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = String(localized: "\(app.name) · Export compliance key")
        guard let status = try EncryptionKeyReport.Status(rawValue: arguments.string("status")) else {
            return .refused(String(localized: "status is added, alreadyThere or couldNotAdd."), target: target)
        }
        let value: EncryptionKeyValue?
        if let text = try arguments.optionalString("value") {
            guard let parsed = EncryptionKeyValue(text: text) else { return .refused(String(localized: "value is NO or YES."), target: target) }
            value = parsed
        } else {
            value = nil
        }
        let code = try arguments.optionalString("complianceCode")
        let places: [EncryptionKeyReport.Place]
        switch try Self.places(arguments) {
        case let .success(parsed): places = parsed
        case let .failure(refusal): return .refused(refusal.reason, target: target)
        }
        let reason = try arguments.optionalString("reason")
        if let refusal = Self.refusal(status: status, value: value, code: code, places: places, reason: reason) {
            return .refused(refusal, target: target)
        }

        let state = try await MCPExportComplianceState.load(app, in: context)
        let readiness = state.keyReadiness
        if status != .couldNotAdd, let value, let answer = readiness.answer {
            if let contradiction = Self.contradiction(value: value, code: code, answer: answer) {
                return .refused(contradiction, target: target, details: ["expected": .string(answer.value.rawValue)])
            }
        }
        let report = try EncryptionKeyReport(
            appID: app.id, status: status, value: value, code: value == .yes ? code : nil, places: places,
            commit: arguments.optionalString("commit"), reason: reason, notes: arguments.optionalString("notes"),
            client: context.clientName, date: now()
        )
        store.setReport(report)
        var result: [String: JSONValue] = ["status": "saved", "shows": .string(report.headline)]
        if status != .couldNotAdd, let why = readiness.reason {
            result["warning"] = .string(String(localized: """
            Atlas's answer isn't settled yet (\(why.text)) The person sees your report, and the page warns if the answers \
            end up saying something else than the key.
            """))
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// What's missing or doesn't fit the status.
    static func refusal(
        status: EncryptionKeyReport.Status, value: EncryptionKeyValue?, code: String?, places: [EncryptionKeyReport.Place], reason: String?
    ) -> String? {
        switch status {
        case .couldNotAdd:
            return reason == nil ? String(localized: "With couldNotAdd, say why in reason.") : nil
        case .added, .alreadyThere:
            guard let value else { return String(localized: "Say what the key says now: value NO or YES.") }
            if value == .yes, code == nil {
                return String(localized: "With YES, give complianceCode: the approved encryption declaration's codeValue (ITSEncryptionExportComplianceCode).")
            }
            guard !places.isEmpty else { return String(localized: "Say where the key is set: where, with the file and target.") }
            return nil
        }
    }

    /// The key against the answer settled in Atlas.
    static func contradiction(value: EncryptionKeyValue, code: String?, answer: EncryptionKeyAnswer) -> String? {
        if value != answer.value {
            return String(localized: """
            Atlas's settled answer is \(answer.value.meaning), from \(answer.basisText), so the key is \(answer.value.rawValue), \
            not \(value.rawValue). Change it to \(answer.value.rawValue) in the project and report again; if the answer is \
            wrong, the person changes it on the Export Compliance page first.
            """)
        }
        if value == .yes, let expected = answer.code, code != expected {
            return String(localized: "The approved declaration's code is \(expected): set ITSEncryptionExportComplianceCode to it and report again.")
        }
        return nil
    }

    /// `where` as places, or what's wrong with one.
    private static func places(_ arguments: MCPToolArguments) throws -> Result<[EncryptionKeyReport.Place], ComplianceAnswerRefusal> {
        let items = try arguments.optionalArray("where") ?? []
        var places: [EncryptionKeyReport.Place] = []
        for (index, item) in items.enumerated() {
            guard let object = item.objectValue,
                  let file = object["file"]?.stringValue?.trimmingCharacters(in: .whitespaces), !file.isEmpty,
                  let target = object["target"]?.stringValue?.trimmingCharacters(in: .whitespaces), !target.isEmpty
            else {
                return .failure(ComplianceAnswerRefusal(String(localized: "where[\(index)] needs file and target.")))
            }
            let line = object["line"]?.intValue
            let setting = object["buildSetting"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            guard line != nil || setting != nil else {
                return .failure(ComplianceAnswerRefusal(String(localized: "where[\(index)] needs the key's line in the file, or its buildSetting.")))
            }
            let configurations = object["configurations"]?.arrayValue?.compactMap(\.stringValue) ?? []
            places.append(EncryptionKeyReport.Place(file: file, line: line, buildSetting: setting, target: target, configurations: configurations))
        }
        return .success(places)
    }
}
