//
//  AppInformationViewModel+Export.swift
//  Atlas
//

import Foundation

// Export Compliance: the five answers are kept on this Mac; what they add
// up to goes to the version's build through Review & Push, with the
// encryption declaration an assistant proposed when it isn't exempt
// (`propose_export_compliance`).
extension AppInformationViewModel {
    /// Your answers, else the newest declaration's, else what the build's
    /// flag implies.
    var exportAnswers: ExportComplianceAnswers? {
        guard let export = content?.export else { return nil }
        return notes.exportAnswers ?? export.declaredAnswers ?? ExportComplianceAnswers(usesNonExemptEncryption: export.usesNonExemptEncryption)
    }

    /// Why the answers can't reach App Store Connect yet, if they can't.
    var exportNotice: String? {
        guard let content, content.export.buildID == nil else { return nil }
        let version = content.version?.versionString ?? String(localized: "this version")
        return String(localized: "No build is attached to \(version) yet. The answers are kept here; attach a build in App Store Connect to send them.")
    }

    func setExportAnswer(_ answer: Bool, for question: ExportComplianceQuestion) {
        guard let content, var answers = exportAnswers, answers[question] != answer else { return }
        answers[question] = answer
        notes.exportAnswers = answers
        apply(builder.encryptionChange(content.export, to: answers), id: builder.encryptionChangeID)
        // A declaration only goes with encryption that isn't exempt.
        if answers.usesNonExemptEncryption != true { queue.discard(id: builder.declarationChangeID) }
    }

    /// The encryption declaration waiting in Review & Push, if one does.
    var queuedDeclaration: PendingChange? {
        queue.change(id: builder.declarationChangeID)
    }

    /// Confirm in the evidence popover: the assistant's answers stay, the
    /// popover and banner go.
    func confirmExportEvidence() {
        notes.exportEvidence = nil
        showsExportEvidence = false
    }

    /// Reject: the assistant's answers go, back to what App Store Connect
    /// says.
    func rejectExportEvidence() {
        notes.exportEvidence = nil
        notes.exportAnswers = nil
        showsExportEvidence = false
        queue.discard(ids: [builder.encryptionChangeID, builder.declarationChangeID])
    }
}
