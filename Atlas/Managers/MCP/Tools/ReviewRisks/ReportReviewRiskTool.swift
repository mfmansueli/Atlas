//
//  ReportReviewRiskTool.swift
//  Atlas
//

import Foundation

/// `report_review_risk`: an assistant read the app's project and says
/// whether a risk is there. Confirmed adds it to the app's App Review risks
/// (`ReviewRiskCenter.report`), tagged with who found it; cleared takes it
/// out and counts the check as answered (`ReviewRiskCenter.clear`). It
/// proposes nothing: it changes what Atlas lists.
struct ReportReviewRiskTool: MCPTool {
    var center = ReviewRiskCenter.shared
    /// The fix is one sentence.
    static let adviceLimit = 200

    let definition = MCPToolDefinition(
        name: "report_review_risk",
        title: "Report an App Review risk",
        description: """
        After reading the app's project for a check in get_review_risks' projectChecks (or a risk it lists), \
        confirm or clear it. confirmed: the risk is there; send title (at most 8 words, result first), why (one \
        sentence, one number), evidence (file:line), advice (the fix, one sentence), level and howSure. cleared: it \
        isn't; send evidence where the code shows it (Settings/AccountView.swift:88 for Delete Account). riskId \
        names a listed risk; without it, cleared clears every risk of the check. The person sees it in Atlas.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "check": [
                    "type": "string",
                    "enum": .array(ReviewRiskCheckID.allCases.map { .string($0.mcpName) }),
                    "description": "The check, e.g. accountDeletion, signInWithApple or purposeStrings.",
                ],
                "verdict": [
                    "type": "string",
                    "enum": ["confirmed", "cleared"],
                    "description": "confirmed: the risk is in the project. cleared: you read the code and it isn't.",
                ],
                "riskId": MCPToolDefinition.string("Optional: the risk's id from get_review_risks, e.g. purposeStrings:missing.NSCameraUsageDescription."),
                "title": MCPToolDefinition.string("For confirmed: what App Review would reject, at most 8 words, e.g. “No way to delete an account”."),
                "why": MCPToolDefinition.shortWhy("For confirmed: what you found, with one number."),
                "evidence": MCPToolDefinition.string("Where in the project, as file:line, e.g. Login/SignUpView.swift:42."),
                "excerpt": MCPToolDefinition.string("Optional: the line as written there."),
                "advice": MCPToolDefinition.string("For confirmed: the fix, one sentence, at most \(ReportReviewRiskTool.adviceLimit) characters."),
                "level": [
                    "type": "string",
                    "enum": .array(ReviewRiskLevel.allCases.map { .string($0.rawValue) }),
                    "description": "For confirmed: blocksReview (rejected or refused for sure), likely (a common rejection) or check (worth a look).",
                ],
                "howSure": [
                    "type": "integer",
                    "minimum": .int(1),
                    "maximum": .int(3),
                    "description": "For confirmed: 1 (not very sure), 2 (fairly sure, the default) or 3 (sure).",
                ],
            ],
            required: ["appId", "check", "verdict", "evidence"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = String(localized: "\(app.name) · App Review risks", comment: "kind:label · an activity log line's subject")
        let checkName = try arguments.string("check")
        guard let check = ReviewRiskCheckID(rawValue: checkName) else {
            let names = ReviewRiskCheckID.allCases.map(\.mcpName).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "check", expected: String(localized: "one of \(names)", comment: "kind:error"))
        }
        let evidence = try arguments.string("evidence")
        let riskID = try arguments.optionalString("riskId")
        if let riskID, !riskID.hasPrefix("\(check.mcpName):") || riskID.count <= check.mcpName.count + 1 {
            return .refused(
                String(
                    localized: "riskId \(riskID) isn’t a \(check.mcpName) risk. Send an id get_review_risks lists for it, or leave riskId out.",
                    comment: "kind:error"
                ),
                target: target
            )
        }
        switch try arguments.string("verdict") {
        case "confirmed":
            return try confirm(check, riskID: riskID, arguments: arguments, app: app, context: context, target: target)
        case "cleared":
            return clear(check, riskID: riskID, evidence: evidence, app: app, context: context, target: target)
        default:
            throw MCPToolError.invalidArgument(name: "verdict", expected: String(localized: "confirmed or cleared", comment: "kind:error"))
        }
    }

    // MARK: - Confirmed

    private func confirm(
        _ check: ReviewRiskCheckID,
        riskID: String?,
        arguments: MCPToolArguments,
        app: StoreApp,
        context: MCPToolContext,
        target: String
    ) throws -> MCPToolOutcome {
        let evidence = try arguments.string("evidence")
        guard let title = try arguments.optionalString("title") else {
            return .refused(String(localized: "title is missing: say what App Review would reject, at most 8 words.", comment: "kind:error"), target: target)
        }
        guard let why = try arguments.optionalString("why") else {
            return .refused(String(localized: "why is missing: one sentence with the number that shows it.", comment: "kind:error"), target: target)
        }
        guard let advice = try arguments.optionalString("advice") else {
            return .refused(String(localized: "advice is missing: say the fix in one sentence.", comment: "kind:error"), target: target)
        }
        if let refusal = Self.textRefusal(title: title, why: why, advice: advice) { return .refused(refusal, target: target) }
        guard let levelName = try arguments.optionalString("level"), let level = ReviewRiskLevel(rawValue: levelName) else {
            throw MCPToolError.invalidArgument(name: "level", expected: String(localized: "blocksReview, likely or check", comment: "kind:error"))
        }
        let howSureNumber = try arguments.optionalInt("howSure") ?? HowSure.fairlySure.rawValue
        guard let howSure = HowSure(rawValue: howSureNumber) else {
            throw MCPToolError.invalidArgument(name: "howSure", expected: String(localized: "1, 2 or 3", comment: "kind:error"))
        }
        let subject = riskID.map { String($0.dropFirst(check.mcpName.count + 1)) } ?? "app"
        let excerpt = try arguments.optionalString("excerpt") ?? ""
        let risk = ReviewRisk(
            check: check,
            subject: subject,
            level: level,
            title: title,
            why: why,
            evidence: [ReviewRiskEvidence(place: evidence, excerpt: excerpt)],
            howSure: howSure,
            fix: ReviewRiskFix(advice: advice),
            foundBy: context.clientName
        )
        center.report(risk, for: app.id)
        let result: JSONValue = [
            "status": "confirmed",
            "riskId": .string(risk.id),
            "say": "It shows in Atlas’s App Review risks. Tell the person the title, why and the fix.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// Why a confirmed risk's texts can't be shown, or nil: the title's
    /// limits, the why's, the advice's length, and the words Atlas never writes.
    static func textRefusal(title: String, why: String, advice: String) -> String? {
        if let refusal = AssistantTextLimits.titleRefusal(title, field: "title") { return refusal }
        if let refusal = AssistantTextLimits.whyRefusal(why, field: "why", hasDetails: false) { return refusal }
        if advice.count > adviceLimit {
            return String(localized: "advice is \(advice.count) characters; at most \(adviceLimit). Keep the fix, one sentence.", comment: "kind:error")
        }
        for (field, text) in [("title", title), ("why", why), ("advice", advice)] {
            if text.contains("!") {
                return String(localized: "\(field) has “!”; Atlas never writes it. Rewrite it plainly.", comment: "kind:error")
            }
            let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            if let banned = words.intersection(MCPPriceEvidence.bannedWords).sorted().first {
                return String(localized: "\(field) uses “\(banned)”; Atlas never writes it. Rewrite it without it.", comment: "kind:error")
            }
        }
        return nil
    }

    // MARK: - Cleared

    private func clear(
        _ check: ReviewRiskCheckID,
        riskID: String?,
        evidence: String,
        app: StoreApp,
        context: MCPToolContext,
        target: String
    ) -> MCPToolOutcome {
        var ids: [String]
        if let riskID {
            ids = [riskID]
        } else {
            ids = center.lastReport(for: app.id)?.risks.filter { $0.check == check }.map(\.id) ?? []
            let general = "\(check.mcpName):app"
            if !ids.contains(general) { ids.append(general) }
        }
        let date = center.now()
        for id in ids {
            center.clear(ReviewRiskVerdict(check: check, riskID: id, author: context.clientName, evidence: evidence, date: date), for: app.id)
        }
        let result: JSONValue = [
            "status": "cleared",
            "riskIds": .array(ids.map(JSONValue.string)),
            "say": "Atlas no longer lists it, and get_review_risks counts the check as answered.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}
