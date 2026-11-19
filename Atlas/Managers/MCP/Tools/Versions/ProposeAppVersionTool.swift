//
//  ProposeAppVersionTool.swift
//  Atlas
//

import Foundation

/// `propose_app_version`: a new App Store version, queued in Review & Push
/// as "Create version 1.5", the assistant's, like the New Version sheet
/// queues it. App Store Connect creates it when the person pushes; until
/// then they can discard it. A later proposal for the same platform
/// replaces the assistant's own, never the person's.
struct ProposeAppVersionTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_app_version",
        title: "Propose a new app version",
        description: """
        Proposes a new App Store version: versionString (one to three whole numbers, higher than the latest, e.g. \
        the project's MARKETING_VERSION), platform (IOS, MAC_OS, VISION_OS or TV_OS; IOS when left out and the app \
        has it), and a reason with evidence. It's queued in Review & Push (status "queued") and App Store Connect \
        creates it, in Prepare for Submission, when the person pushes; its texts can be proposed once it exists. \
        "unchanged" means it's already queued; "refused" says why, e.g. a version still in progress on that platform.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "versionString": MCPToolDefinition.string("e.g. 1.5"),
                "platform": MCPToolDefinition.string("IOS, MAC_OS, VISION_OS or TV_OS."),
                "reason": MCPToolDefinition.string("Why this number, in a sentence the person can check."),
                "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. Lumen.xcodeproj — MARKETING_VERSION = 1.5"],
            ],
            required: ["appId", "versionString"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let versions = try await MCPAppVersions.load(app, in: context)
        let platform: String
        if let name = try arguments.optionalString("platform") {
            guard let known = MCPAppVersions.platform(named: name) else {
                throw MCPToolError.invalidArgument(name: "platform", expected: String(localized: "IOS, MAC_OS, VISION_OS or TV_OS"))
            }
            platform = known
        } else {
            platform = versions.platforms.first ?? StorePageVersion.iOSPlatform
        }
        let version = try NewAppVersion(versionString: arguments.string("versionString"), platform: platform)
        let target = String(localized: "\(app.name) · Version \(version.versionString) · \(version.platformTitle)")
        let refuse = { (reason: String) in
            let result: JSONValue = ["status": "refused", "versionString": .string(version.versionString), "reason": .string(reason)]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reason)])
        }
        if let queued = versions.queued(on: platform) {
            if queued.version == version {
                let result: JSONValue = ["status": "unchanged", "changeId": .string(queued.change.id), "versionString": .string(version.versionString)]
                return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .read)])
            }
            if queued.change.source != context.source {
                return refuse(String(localized: "\(queued.change.source.title) already queued version \(queued.version.versionString) for \(version.platformTitle) in Review & Push."))
            }
        }
        if let problem = NewAppVersionRules.problem(for: version, in: versions.versions) {
            return refuse(problem.message)
        }
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let reason = try [arguments.optionalString("reason"), evidence.isEmpty ? nil : evidence.joined(separator: "; ")]
            .compactMap(\.self)
            .joined(separator: " ")
        let change = NewAppVersionChangeBuilder(appID: app.id).change(
            for: version,
            showsPlatform: versions.platforms.count > 1,
            source: context.source,
            reason: reason
        )
        context.workspace.changes.upsert(change)
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(change.id),
            "versionString": .string(version.versionString),
            "platform": .string(platform),
            "note": """
            It waits in Review & Push until the person pushes; App Store Connect then creates it in Prepare for \
            Submission. Propose its What's New with propose_listing_text once it exists.
            """,
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
