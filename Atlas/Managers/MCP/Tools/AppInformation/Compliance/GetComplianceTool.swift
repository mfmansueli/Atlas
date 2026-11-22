//
//  GetComplianceTool.swift
//  Atlas
//

import Foundation

/// `get_compliance`: the App Compliance page of an app, as the person sees
/// it: each regulation, whether Apple asks about it, the person's answer,
/// the answers an assistant may propose, and the trader details Atlas
/// prepared.
struct GetComplianceTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_compliance",
        title: "Read App Compliance",
        description: """
        Returns an app's App Compliance page: each regulation (traderStatus for the EU's Digital Services Act, \
        icpFilingNumber, securityAssessment and aiGeneratedContent for China mainland (asked of every app, sold there \
        or not: one not sold there, or stopping sales there, answers No, marked assumed), vietnamGameLicense, \
        medicalDevice), its state (needsAnswer, toEnter, \
        notPushed, passes), what Apple asks, the person's current answer, the answers you may propose with \
        propose_compliance_answers (empty when it takes none, with why), an open suggestion if there is one, and \
        the trader details Atlas prepared from the team's name and App Review's contact. Apple's API takes none of \
        these answers: the person enters them in App Store Connect, except stopping sales in China mainland, which \
        is pushed. Each regulation's pushedAnswers lists the answers that become a change in Review & Push once \
        accepted (stopSelling); every other answer is kept in Atlas until the person enters it in App Store Connect \
        and marks it as declared. Export compliance (encryption) is get_export_compliance.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        ),
        proposalKind: nil
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let state = try await MCPComplianceState.load(app, in: context)
        let report = state.report
        let result: JSONValue = [
            "app": ["appId": .string(app.id), "name": .string(app.name)],
            "summary": .string(report.headline),
            "regulations": .array(ComplianceRule.allCases.map { regulation($0, in: state) }),
            "preparedTraderDetails": Self.json(state.preparedTraderDetails),
            "note": """
            Every answer you propose waits on its card until the person accepts it; Accept All never takes them. \
            Accepting stopSelling queues a change in Review & Push; the person enters every other answer in App \
            Store Connect. Never make up an address, a phone number or an ICP Filing Number.
            """,
        ]
        return .read(result, target: String(localized: "\(app.name) · App Compliance"))
    }

    private func regulation(_ rule: ComplianceRule, in state: MCPComplianceState) -> JSONValue {
        let report = state.report
        var object: [String: JSONValue] = [
            "rule": .string(rule.rawValue),
            "title": .string(rule.title),
            "state": .string(Self.name(of: report.state(of: rule))),
            "detail": .string(report.detail(for: rule)),
            "answer": answer(rule, in: report),
        ]
        if let refusal = report.refusal(for: rule) {
            object["proposable"] = .array([])
            object["whyNotProposable"] = .string(refusal)
        } else {
            object["proposable"] = .array(ComplianceSuggestedAnswer.names(for: rule).map { .string($0) })
        }
        object["pushedAnswers"] = rule == .icpFilingNumber ? ["stopSelling"] : []
        if let suggestion = state.suggestion(for: rule) {
            object["openSuggestion"] = [
                "answer": .string(suggestion.answer.mcpName),
                "by": .string(suggestion.client),
                "why": .string(suggestion.evidence.why),
            ]
        }
        return .object(object)
    }

    /// The person's answer so far, or null.
    private func answer(_ rule: ComplianceRule, in report: ComplianceReport) -> JSONValue {
        let answers = report.answers
        switch rule {
        case .traderStatus:
            switch answers.trader {
            case .trader: return ["answer": "trader", "traderDetails": Self.json(answers.traderDetails ?? TraderDetails())]
            case .nonTrader: return ["answer": "nonTrader"]
            case nil: return .null
            }
        case .icpFilingNumber:
            if report.stopsSellingInChina { return ["answer": "stopSelling"] }
            return answers.addsICPNumber ? ["answer": "icpNumber", "icpNumber": .string(answers.icpNumber)] : .null
        case .securityAssessment, .aiGeneratedContent:
            return chinaAnswer(rule, in: report)
        case .vietnamGameLicense:
            return answers.declared.contains(rule) ? ["answer": "declared"] : .null
        case .medicalDevice:
            if answers.declared.contains(rule) { return ["answer": "declared"] }
            return answers.regulatedMedicalDevice.map { ["answer": .string($0 ? "regulated" : "notRegulated")] } ?? .null
        }
    }

    /// A China mainland declaration's answer: declared, Yes or No (assumed
    /// when it comes from where the app is sold), and the AI filing with a
    /// Yes.
    private func chinaAnswer(_ rule: ComplianceRule, in report: ComplianceReport) -> JSONValue {
        if report.answers.declared.contains(rule) { return ["answer": "declared"] }
        if report.answersNoForWhereItSells(rule) {
            let reason = report.stopsSellingInChina ? "stoppingSalesInChinaMainland" : "notSoldInChinaMainland"
            return ["answer": rule == .securityAssessment ? "noAssessment" : "noAI", "assumed": .string(reason)]
        }
        if rule == .securityAssessment {
            return report.securityAssessmentAnswer.map { ["answer": .string($0 ? "needsAssessment" : "noAssessment")] } ?? .null
        }
        guard let content = report.aiContentAnswer else { return .null }
        guard content.offersAI else { return ["answer": "noAI"] }
        let filing = content.filing.trimmed
        return [
            "answer": "offersAI",
            "aiFiling": [
                "kind": .string(filing.kind.rawValue), "number": .string(filing.number), "name": .string(filing.name),
                "technologyOwner": .string(filing.technologyOwner),
            ],
        ]
    }

    static func json(_ details: TraderDetails) -> JSONValue {
        .object(Dictionary(uniqueKeysWithValues: TraderDetailField.allCases.map { ($0.rawValue, JSONValue.string(details[$0])) }))
    }

    static func name(of state: ComplianceItemState) -> String {
        switch state {
        case .needsAnswer: "needsAnswer"
        case .toEnter: "toEnter"
        case .notPushed: "notPushed"
        case .passes: "passes"
        }
    }
}
