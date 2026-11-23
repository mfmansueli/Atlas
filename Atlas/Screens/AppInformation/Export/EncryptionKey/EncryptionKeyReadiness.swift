//
//  EncryptionKeyReadiness.swift
//  Atlas
//

import Foundation

/// Whether Atlas may ask an assistant to add the export compliance key
/// (Add It to the Project), and with what value. Only a settled answer
/// counts: the person's own or confirmed answers, or the build's flag when
/// nothing contradicts it. A wrong NO in every build is an export
/// declaration, so an assistant's unconfirmed suggestion never does.
enum EncryptionKeyReadiness: Hashable, Sendable {
    case ready(EncryptionKeyAnswer)
    case blocked(Reason)

    enum Reason: Hashable, Sendable {
        /// Nothing answers the question yet.
        case notAnswered
        /// The app uses encryption, but whether it's exempt isn't answered.
        case incomplete
        /// An assistant's answers wait for Confirm or Reject.
        case unconfirmedSuggestion(client: String)
        /// The build says exempt and the newest declaration says otherwise,
        /// or the other way round.
        case contradicts(buildNumber: String?)
        /// Not exempt, and no approved declaration with these answers has
        /// a code for the key to name.
        case needsApprovedDeclaration

        /// Why Add It to the Project is off, under the button.
        var text: String {
            switch self {
            case .notAnswered:
                String(localized: "Answer the questions above first: the key gives the same answer for every build.")
            case .incomplete:
                String(localized: "Answer whether all of the encryption is exempt first.")
            case let .unconfirmedSuggestion(client):
                String(localized: "Confirm or reject \(client)’s answers first: a wrong No in every build is a false export declaration.")
            case let .contradicts(number?):
                String(localized: "Build \(number)’s answer and the app’s encryption declaration disagree. Answer the questions above first.")
            case .contradicts(nil):
                String(localized: "The build’s answer and the app’s encryption declaration disagree. Answer the questions above first.")
            case .needsApprovedDeclaration:
                String(localized: """
                The encryption isn’t exempt, so the key must name an approved encryption declaration’s code, and none with \
                these answers is approved yet.
                """)
            }
        }

        /// For `get_export_compliance`.
        var code: String {
            switch self {
            case .notAnswered: "notAnswered"
            case .incomplete: "incomplete"
            case .unconfirmedSuggestion: "unconfirmedSuggestion"
            case .contradicts: "contradicts"
            case .needsApprovedDeclaration: "needsApprovedDeclaration"
            }
        }
    }

    var answer: EncryptionKeyAnswer? {
        if case let .ready(answer) = self { return answer }
        return nil
    }

    var reason: Reason? {
        if case let .blocked(reason) = self { return reason }
        return nil
    }

    /// From what Atlas keeps (`notes`) and what App Store Connect says
    /// (`export`).
    static func make(notes: AppInformationNotes, export: ExportComplianceValues) -> EncryptionKeyReadiness {
        if let evidence = notes.exportEvidence { return .blocked(.unconfirmedSuggestion(client: evidence.client)) }
        if let answers = notes.exportAnswers {
            guard let uses = answers.usesNonExemptEncryption else {
                return .blocked(answers[.usesEncryption] == nil ? .notAnswered : .incomplete)
            }
            return answer(uses: uses, answers: answers, export: export, basis: .confirmed)
        }
        guard let uses = export.usesNonExemptEncryption else { return .blocked(.notAnswered) }
        if let declared = export.declaredAnswers?.usesNonExemptEncryption, declared != uses {
            return .blocked(.contradicts(buildNumber: export.buildNumber))
        }
        let answers = export.declaredAnswers ?? ExportComplianceAnswers(usesNonExemptEncryption: uses)
        return answer(uses: uses, answers: answers, export: export, basis: .build(number: export.buildNumber))
    }

    private static func answer(
        uses: Bool, answers: ExportComplianceAnswers, export: ExportComplianceValues, basis: EncryptionKeyAnswer.Basis
    ) -> EncryptionKeyReadiness {
        guard uses else { return .ready(EncryptionKeyAnswer(value: .no, basis: basis)) }
        guard let declaration = approvedDeclaration(for: answers, in: export.declarations), let code = declaration.codeValue else {
            return .blocked(.needsApprovedDeclaration)
        }
        return .ready(EncryptionKeyAnswer(value: .yes, code: code, declarationID: declaration.id, basis: basis))
    }

    /// The approved declaration with these answers and a code, newest
    /// first.
    static func approvedDeclaration(for answers: ExportComplianceAnswers, in declarations: [ExportEncryptionDeclaration]) -> ExportEncryptionDeclaration? {
        declarations.first { $0.isApproved && $0.matches(answers) && !($0.codeValue ?? "").isEmpty }
    }
}
