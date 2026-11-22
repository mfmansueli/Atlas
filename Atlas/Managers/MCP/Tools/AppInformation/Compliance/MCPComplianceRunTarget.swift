//
//  MCPComplianceRunTarget.swift
//  Atlas
//

import Foundation

/// App Compliance and Export Compliance in a Suggest Everything run. They
/// aren't field suggestions (the answers wait on their pages, and Accept
/// All never takes them), but a run plans and counts them like fields:
/// `{area: info, page: appCompliance, field: <rule>}` per regulation and
/// `{area: info, page: exportCompliance, field: encryption}`.
/// `propose_compliance_answers` and `propose_export_compliance` mark them
/// arrived.
enum MCPComplianceRunTarget {
    /// Export Compliance's one planned field.
    static let encryptionField = "encryption"

    static func target(for rule: ComplianceRule) -> SuggestionTarget {
        SuggestionTarget(.appInformation(.appCompliance), field: rule.rawValue)
    }

    static var encryption: SuggestionTarget {
        SuggestionTarget(.appInformation(.exportCompliance), field: encryptionField)
    }

    /// The page a plan entry names when it's one of these; nil for any
    /// other page, which `suggest_fields` checks.
    static func page(named name: String?) -> AppInformationPage? {
        switch name?.replacingOccurrences(of: "_", with: "").lowercased() {
        case "appcompliance", "compliance": .appCompliance
        case "exportcompliance", "export", "encryption": .exportCompliance
        default: nil
        }
    }

    /// A `begin_suggestions` entry for App Compliance or Export Compliance;
    /// nil when it names another page. A regulation Apple doesn't ask about
    /// here is skipped with why.
    static func planned(_ item: MCPSuggestionItem, report: ComplianceReport?) -> Result<SuggestionTarget, MCPPlanSkip>? {
        guard item.area == .appInformation, let page = page(named: item.page) else { return nil }
        if page == .exportCompliance {
            guard item.field.lowercased() == encryptionField else {
                return .failure(.refused(.unknownField(item.field, known: [encryptionField])))
            }
            return .success(encryption)
        }
        let proposable = ComplianceRule.allCases.filter { !ComplianceSuggestedAnswer.names(for: $0).isEmpty }
        guard let rule = ComplianceRule(rawValue: item.field), proposable.contains(rule) else {
            return .failure(.refused(.unknownField(item.field, known: proposable.map(\.rawValue))))
        }
        if let refusal = report?.refusal(for: rule) {
            return .failure(.refused(.invalidValue(refusal)))
        }
        return .success(target(for: rule))
    }

    /// Whether a plan has an App Compliance entry, so `begin_suggestions`
    /// reads the page first.
    static func plansCompliance(_ items: [MCPSuggestionItem]) -> Bool {
        items.contains { $0.area == .appInformation && page(named: $0.page) == .appCompliance }
    }

    /// Counts an answer toward the run, sent with its id or planned.
    @MainActor
    static func noteArrival(of target: SuggestionTarget, appID: StoreApp.ID, runID: SuggestionRun.ID?, context: MCPToolContext) {
        context.workspace.suggestions?.noteSettled(target, appID: appID, source: .assistant(client: context.clientName), runID: runID)
    }

    /// The refusal for a call sent with a run the person stopped.
    @MainActor
    static func stoppedRun(_ runID: SuggestionRun.ID?, context: MCPToolContext) -> MCPSuggestionRefusal? {
        guard let runID, context.workspace.suggestions?.isStopped(runID) == true else { return nil }
        return .runStopped
    }
}
