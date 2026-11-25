//
//  GetReviewRisksTool.swift
//  Atlas
//

import Foundation

/// `get_review_risks`: what App Review may reject in an app, from every
/// check Atlas runs (`ReviewRiskEngine`): subscription terms, products
/// for review, links, store texts in every language, age rating, user
/// content, What's New, trademarks, paying elsewhere, similar apps, text in
/// screenshots, China mainland's declarations, and the project checks an
/// assistant confirms with `report_review_risk`. Read-only.
struct GetReviewRisksTool: MCPTool {
    var center = ReviewRiskCenter.shared

    let definition = MCPToolDefinition(
        name: "get_review_risks",
        title: "Get App Review risks",
        description: """
        Lists what App Review may reject in an app, most serious first (level blocksReview, likely or check), each \
        with the guideline, title, why, evidence (place and the words as written), howSure and a fix: advice, and \
        the propose_ tool and arguments that start it when an assistant can. notChecked says which checks couldn't \
        run and why. projectChecks are the checks only the app's code can answer (account deletion, Sign in with \
        Apple, permission texts): read the project, then confirm or clear each with report_review_risk. Start here \
        when the person asks whether the app is ready for App Review. A report younger than 10 minutes is reused \
        unless refresh is true.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "refresh": [
                    "type": "boolean",
                    "description": "Run every check again instead of reusing a report younger than 10 minutes.",
                ],
            ],
            required: ["appId"]
        ),
        proposalKind: nil
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let workspace = context.workspace
        let app = try await workspace.app(matching: arguments.string("appId"))
        let loader = ReviewRiskFactsLoader(
            services: workspace.services, changes: workspace.changes, apps: workspace.apps, launcher: context.launcher
        )
        let report = try await center.check(app, loader: loader, refresh: arguments.optionalBool("refresh") ?? false)
        return .read(Self.json(report), target: String(localized: "\(app.name) · App Review risks"))
    }

    static func json(_ report: ReviewRiskReport) -> JSONValue {
        let projectChecks = ReviewRiskCheckID.allCases.filter(\.needsProject).map { check -> JSONValue in
            [
                "check": .string(check.mcpName),
                "guideline": .string(check.guideline),
                "answered": .bool(!report.notChecked.contains { $0.check == check }),
            ]
        }
        return [
            "app": ["appId": .string(report.appID), "name": .string(report.appName)],
            "summary": .string(report.summary),
            "checkedAt": .string(report.checkedAt.ISO8601Format()),
            "version": report.versionString.map(JSONValue.string) ?? .null,
            "risks": .array(report.risks.map(json)),
            "notChecked": .array(report.notChecked.map { gap in
                ["check": .string(gap.check.mcpName), "guideline": .string(gap.check.guideline), "reason": .string(gap.reason)]
            }),
            "dismissedByThePerson": .int(report.dismissedCount),
            "projectChecks": .array(projectChecks),
            "note": """
            Tell the person each risk in their words: title, why, then the fix. Propose the fix with the tool named in \
            fix when there is one; App Store Connect-only fixes (App Compliance, the license agreement) are the \
            person's. Never say the app is ready for App Review while notChecked or unanswered projectChecks remain.
            """,
        ]
    }

    static func json(_ risk: ReviewRisk) -> JSONValue {
        var fix: [String: JSONValue] = ["advice": .string(risk.fix.advice)]
        if let tool = risk.fix.tool { fix["tool"] = .string(tool) }
        if !risk.fix.arguments.isEmpty { fix["arguments"] = .object(risk.fix.arguments.mapValues(JSONValue.string)) }
        var object: [String: JSONValue] = [
            "id": .string(risk.id),
            "check": .string(risk.check.mcpName),
            "guideline": .string(risk.guideline),
            "level": .string(risk.level.rawValue),
            "title": .string(risk.title),
            "why": .string(risk.why),
            "howSure": .int(risk.howSure.rawValue),
            "evidence": .array(risk.evidence.map { evidence in
                var item: [String: JSONValue] = ["place": .string(evidence.place)]
                if !evidence.excerpt.isEmpty { item["excerpt"] = .string(evidence.excerpt) }
                if let locale = evidence.locale { item["locale"] = .string(locale) }
                return .object(item)
            }),
            "fix": .object(fix),
            "section": .string(risk.check.section.rawValue),
        ]
        if let finder = risk.foundBy { object["foundBy"] = .string(finder) }
        return .object(object)
    }
}
