//
//  ComplianceSuggestedAnswer+MCP.swift
//  Atlas
//

import Foundation

// `propose_compliance_answers`' answer names: trader and nonTrader for the
// Digital Services Act, icpNumber and stopSelling for China mainland's ICP,
// needsAssessment and noAssessment for its Security Assessment, offersAI
// (with aiFiling) and noAI for its AI content declaration, regulated and
// notRegulated for the medical device question.
extension ComplianceSuggestedAnswer {
    /// The answer names each regulation takes.
    static func names(for rule: ComplianceRule) -> [String] {
        switch rule {
        case .traderStatus: ["trader", "nonTrader"]
        case .icpFilingNumber: ["icpNumber", "stopSelling"]
        case .securityAssessment: ["needsAssessment", "noAssessment"]
        case .aiGeneratedContent: ["offersAI", "noAI"]
        case .medicalDevice: ["regulated", "notRegulated"]
        case .vietnamGameLicense: []
        }
    }

    var mcpName: String {
        switch self {
        case .trader: "trader"
        case .nonTrader: "nonTrader"
        case .icpNumber: "icpNumber"
        case .stopSellingInChina: "stopSelling"
        case .medicalDevice(isRegulated: true): "regulated"
        case .medicalDevice(isRegulated: false): "notRegulated"
        case .securityAssessment(isNeeded: true): "needsAssessment"
        case .securityAssessment(isNeeded: false): "noAssessment"
        case let .aiContent(answer): answer.offersAI ? "offersAI" : "noAI"
        }
    }

    /// The answer an item asks for, or why it can't be taken. A trader's
    /// details start from the prepared ones; what the item gives replaces
    /// them field by field.
    static func parse(
        _ object: [String: JSONValue],
        rule: ComplianceRule,
        prepared: TraderDetails
    ) -> Result<ComplianceSuggestedAnswer, ComplianceAnswerRefusal> {
        let name = object["answer"]?.stringValue ?? ""
        let allowed = names(for: rule)
        guard allowed.contains(name) else {
            return .failure(ComplianceAnswerRefusal(String(localized: "\(rule.rawValue) is answered \(allowed.formatted(.list(type: .or))).")))
        }
        switch name {
        case "trader":
            return trader(object["traderDetails"]?.objectValue ?? [:], prepared: prepared)
        case "nonTrader":
            return .success(.nonTrader)
        case "icpNumber":
            return icpNumber(object["icpNumber"]?.stringValue ?? "")
        case "stopSelling":
            return .success(.stopSellingInChina)
        case "needsAssessment", "noAssessment":
            return .success(.securityAssessment(isNeeded: name == "needsAssessment"))
        case "noAI":
            return .success(.aiContent(AIContentAnswer(offersAI: false)))
        case "offersAI":
            return aiFiling(object["aiFiling"]?.objectValue ?? [:]).map { .aiContent(AIContentAnswer(offersAI: true, filing: $0)) }
        default:
            return .success(.medicalDevice(isRegulated: name == "regulated"))
        }
    }

    /// A trader with the prepared details, replaced by the given ones
    /// field by field.
    private static func trader(_ given: [String: JSONValue], prepared: TraderDetails) -> Result<ComplianceSuggestedAnswer, ComplianceAnswerRefusal> {
        var details = prepared
        for field in TraderDetailField.allCases {
            if let text = given[field.rawValue]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                details[field] = text
            }
        }
        guard !details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(ComplianceAnswerRefusal(String(localized: "A trader needs a name: send traderDetails.name.")))
        }
        return .success(.trader(details))
    }

    private static func icpNumber(_ text: String) -> Result<ComplianceSuggestedAnswer, ComplianceAnswerRefusal> {
        let number = ICPFilingNumber.normalized(text)
        guard ICPFilingNumber.isValid(number) else {
            return .failure(ComplianceAnswerRefusal(String(localized: "“\(number)” doesn’t read like an ICP Filing Number, e.g. \(ICPFilingNumber.example).")))
        }
        return .success(.icpNumber(number))
    }

    /// `aiFiling`: {kind: largeLanguageModel | algorithm, number, name,
    /// technologyOwner}. Every field may be missing, since the project may
    /// not show the filing; what's sent must be usable.
    private static func aiFiling(_ object: [String: JSONValue]) -> Result<AIFilingDetails, ComplianceAnswerRefusal> {
        var filing = AIFilingDetails()
        if let kindName = object["kind"]?.stringValue {
            guard let kind = AIFilingKind(rawValue: kindName) else {
                return .failure(ComplianceAnswerRefusal(String(localized: "aiFiling.kind is largeLanguageModel or algorithm.")))
            }
            filing.kind = kind
        }
        filing.number = object["number"]?.stringValue ?? ""
        filing.name = object["name"]?.stringValue ?? ""
        let owner = object["technologyOwner"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filing.usesAnotherCompanysModel = !owner.isEmpty
        filing.technologyOwner = owner
        return .success(filing.trimmed)
    }
}
