//
//  AppInformationViewModel+ComplianceSuggestions.swift
//  Atlas
//

import Foundation

// App Compliance answers an assistant suggested (`propose_compliance_answers`),
// kept in the notes. Each waits on its regulation's card until the person
// accepts or dismisses it; accepting gives the same answer as the card's
// own buttons. Accept All never takes them.
extension AppInformationViewModel {
    /// The assistants' answers still open, in the page's order.
    var complianceSuggestions: [ComplianceSuggestion] {
        guard let report = complianceReport else { return [] }
        let kept = notes.complianceSuggestions
        return ComplianceRule.allCases.compactMap { rule in
            kept.first { $0.rule == rule && $0.isOpen(in: report) }
        }
    }

    func complianceSuggestion(for rule: ComplianceRule) -> ComplianceSuggestion? {
        complianceSuggestions.first { $0.rule == rule }
    }

    /// Above the cards: "suggested 2 answers from the project. Accept each
    /// one yourself…".
    var complianceSuggestionBanner: (client: String, text: String)? {
        let open = complianceSuggestions
        guard let first = open.first else { return nil }
        let clients = Set(open.map(\.client))
        let client = clients.count == 1 ? first.client : String(localized: "Assistants")
        let count = open.count == 1 ? String(localized: "suggested 1 answer") : String(localized: "suggested \(open.count) answers")
        return (client, String(localized: "\(count) from the project. Accept each one yourself: Accept All doesn’t take them."))
    }

    func acceptComplianceSuggestion(for rule: ComplianceRule) {
        guard let suggestion = complianceSuggestion(for: rule) else { return }
        switch suggestion.answer {
        case let .trader(details):
            notes.compliance.traderDetails = details
            decideTrader(.trader)
        case .nonTrader:
            decideTrader(.nonTrader)
        case let .icpNumber(number):
            chooseICP(.addNumber)
            setICPNumber(ICPFilingNumber.normalized(number))
        case .stopSellingInChina:
            stopSellingInChina(source: .assistant(client: suggestion.client))
        case let .medicalDevice(isRegulated):
            notes.compliance.regulatedMedicalDevice = isRegulated
        case let .securityAssessment(isNeeded):
            chooseChina(isNeeded ? .yes : .no, for: .securityAssessment)
        case let .aiContent(answer):
            chooseChina(answer.offersAI ? .yes : .no, for: .aiGeneratedContent)
            if answer.offersAI { setAIFiling(answer.filing.trimmed) }
        }
        removeComplianceSuggestion(for: rule)
        toast = suggestion.answer == .stopSellingInChina
            ? String(localized: "Accepted \(suggestion.client)’s answer. China mainland comes off sale when you push.")
            : String(localized: "Accepted \(suggestion.client)’s answer. Enter it in App Store Connect: Apple’s API doesn’t take it.")
    }

    func dismissComplianceSuggestion(for rule: ComplianceRule) {
        guard let suggestion = complianceSuggestion(for: rule) else { return }
        removeComplianceSuggestion(for: rule)
        toast = String(localized: "Dismissed \(suggestion.client)’s answer.")
    }

    /// Change, under an accepted medical device answer: back to the
    /// question.
    func clearMedicalDeviceAnswer() {
        notes.compliance.regulatedMedicalDevice = nil
    }

    private func removeComplianceSuggestion(for rule: ComplianceRule) {
        notes.complianceSuggestions.removeAll { $0.rule == rule }
    }
}
