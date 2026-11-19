//
//  ProposeComplianceAnswersTool.swift
//  Atlas
//

import Foundation

/// `propose_compliance_answers`: an assistant's answers to the App
/// Compliance page, each with why and its evidence. Each one waits on its
/// regulation's card until the person accepts or dismisses it, replacing
/// an earlier suggestion for the same regulation. Accept All never takes
/// them, and Apple's API takes none of them except stopping sales in China
/// mainland, which becomes a change in Review & Push once accepted.
struct ProposeComplianceAnswersTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_compliance_answers",
        title: "Propose App Compliance answers",
        description: """
        Proposes answers to an app's App Compliance page: answers: [{rule, answer, why, evidence}] with the rules \
        and answer names get_compliance lists as proposable. traderStatus takes trader (with traderDetails: name, \
        address, phone, email; fields you leave out keep the prepared ones) or nonTrader; icpFilingNumber takes \
        icpNumber (with icpNumber) or stopSelling; securityAssessment takes needsAssessment (features like sharing \
        AI-generated content or end-to-end encrypted messaging) or noAssessment; aiGeneratedContent takes offersAI \
        (chatbots, image or video generation, voice or face changes; with aiFiling {kind: largeLanguageModel or \
        algorithm, number, name, technologyOwner when it's another company's model}, as far as the project shows \
        it) or noAI (none, or off or geoblocked in China mainland); medicalDevice takes regulated or notRegulated. \
        Never make up a filing number. Evidence is \
        "file:line — finding" strings; could_not_see says what the project can't show. Each answer waits in Atlas \
        (status "queued") until the person accepts it; "unchanged" means it's already their answer or your open \
        suggestion; "refused" says why.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "answers": [
                    "type": "array",
                    "items": MCPToolDefinition.schema(
                        [
                            "rule": MCPToolDefinition.string("traderStatus, icpFilingNumber, securityAssessment, aiGeneratedContent or medicalDevice."),
                            "answer": MCPToolDefinition.string(
                                "trader, nonTrader, icpNumber, stopSelling, needsAssessment, noAssessment, offersAI, noAI, regulated or notRegulated."
                            ),
                            "traderDetails": MCPToolDefinition.schema([
                                "name": MCPToolDefinition.string("The company or person selling, as on legal pages."),
                                "address": MCPToolDefinition.string("The postal address, only if the project shows it."),
                                "phone": MCPToolDefinition.string("Only if the project shows it."),
                                "email": MCPToolDefinition.string("A contact email."),
                            ]),
                            "icpNumber": MCPToolDefinition.string("e.g. \(ICPFilingNumber.example)"),
                            "aiFiling": MCPToolDefinition.schema([
                                "kind": MCPToolDefinition.string("largeLanguageModel or algorithm."),
                                "number": MCPToolDefinition.string("The CAC's approved filing number, only if the project shows it."),
                                "name": MCPToolDefinition.string("The registered filing name, only if the project shows it."),
                                "technologyOwner": MCPToolDefinition.string("The company whose model it is, when it isn't the person's own."),
                            ]),
                            "why": MCPToolDefinition.string("Why, in a sentence the person can check."),
                            "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. Lumen/Legal/Imprint.md:3 — company address"],
                        ],
                        required: ["rule", "answer"]
                    ),
                ],
                "could_not_see": MCPToolDefinition.string("What the project can't show, e.g. whether you sell as a business."),
            ],
            required: ["appId", "answers"]
        ),
        proposalKind: .appInformation
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let items = try arguments.array("answers")
        let couldNotSee = try arguments.optionalString("could_not_see")
        let state = try await MCPComplianceState.load(app, in: context)
        var notes = state.notes
        var results: [JSONValue] = []
        var logLines: [MCPToolOutcome.LogLine] = []
        for item in items {
            let object = item.objectValue ?? [:]
            let ruleText = object["rule"]?.stringValue ?? ""
            let target = String(localized: "\(app.name) · App Compliance · \(ruleText)")
            let refuse = { (reason: String) in
                results.append(["rule": .string(ruleText), "status": "refused", "reason": .string(reason)])
                logLines.append(MCPToolOutcome.LogLine(target: target, outcome: .refused, reason: reason))
            }
            guard let rule = ComplianceRule(rawValue: ruleText) else {
                refuse(String(localized: "Unknown rule “\(ruleText)”. Use one from get_compliance."))
                continue
            }
            if let refusal = state.report.refusal(for: rule) {
                refuse(refusal)
                continue
            }
            let answer: ComplianceSuggestedAnswer
            switch ComplianceSuggestedAnswer.parse(object, rule: rule, prepared: state.preparedTraderDetails) {
            case let .success(parsed): answer = parsed
            case let .failure(refusal):
                refuse(refusal.reason)
                continue
            }
            let isOpen = notes.complianceSuggestions.contains { $0.answer == answer && $0.isOpen(in: state.report) }
            if answer.isGiven(in: state.report) || isOpen {
                results.append(["rule": .string(rule.rawValue), "status": "unchanged"])
                logLines.append(MCPToolOutcome.LogLine(target: target, outcome: .read))
                continue
            }
            let evidence = AssistantEvidence(
                client: context.clientName,
                summary: answer.title,
                why: object["why"]?.stringValue ?? "",
                evidence: (object["evidence"]?.arrayValue ?? []).compactMap(\.stringValue),
                couldNotSee: couldNotSee
            )
            notes.complianceSuggestions.removeAll { $0.rule == rule }
            notes.complianceSuggestions.append(ComplianceSuggestion(answer: answer, evidence: evidence))
            results.append(["rule": .string(rule.rawValue), "status": "queued", "answer": .string(answer.mcpName)])
            logLines.append(MCPToolOutcome.LogLine(target: target, outcome: .proposed))
        }
        context.workspace.services.appInformation.notes.setNotes(notes, for: app.id)
        let summary: JSONValue = [
            "results": .array(results),
            "note": """
            Each answer waits on its card in App Compliance until the person accepts it. They enter it in App Store \
            Connect themselves: Apple's API doesn't take it.
            """,
        ]
        return MCPToolOutcome(result: summary, isError: false, logLines: logLines)
    }
}
