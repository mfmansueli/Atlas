//
//  AppInformationViewModel+EncryptionKey.swift
//  Atlas
//

import Foundation

// Export Compliance's "Skip the question for every build": whether the
// answer is settled enough for Add It to the Project, and whether the
// page's answers come only from the build's flag.
extension AppInformationViewModel {
    /// Nil until the page has loaded.
    var encryptionKeyReadiness: EncryptionKeyReadiness? {
        content.map { EncryptionKeyReadiness.make(notes: notes, export: $0.export) }
    }

    /// The answers shown are only what build's `usesNonExemptEncryption`
    /// implies: nobody answered them in Atlas, and no declaration has them.
    var exportAnswersAreFromBuild: Bool {
        guard let export = content?.export else { return false }
        return notes.exportAnswers == nil && export.declaredAnswers == nil && export.usesNonExemptEncryption != nil
    }

    /// The card's state, with the app's report, what the project and the
    /// newest builds say, and whether a run is going.
    func encryptionKeyCard(
        report: EncryptionKeyReport?,
        project: EncryptionKeyProjectState,
        builds: [EncryptionKeyBuild],
        answeredInAtlas: Set<String>,
        isRunning: Bool
    ) -> EncryptionKeyCardModel? {
        guard let readiness = encryptionKeyReadiness else { return nil }
        return EncryptionKeyCardModel(
            readiness: readiness,
            detection: EncryptionKeyDetection.detect(report: report, project: project, builds: builds, answeredInAtlas: answeredInAtlas),
            report: report,
            shownValue: exportAnswers?.usesNonExemptEncryption.map(EncryptionKeyValue.init(usesNonExemptEncryption:)),
            isRunning: isRunning
        )
    }
}
