//
//  ReleaseProposalSubmission.swift
//  Atlas
//

import Foundation

/// The Submit sheet's choices an assistant proposed, as `SubmissionPlan`
/// carries them: the build, how the version is released, the phased
/// release, the encryption answer and the In-App Events that go with it.
/// Confirm puts them in the sheet; the person's Submit sends them.
struct ReleaseProposalSubmission: Hashable, Codable, Sendable {
    var buildID: ReleaseBuild.ID
    /// "212".
    var buildNumber: String
    /// `AFTER_APPROVAL`, `MANUAL` or `SCHEDULED`.
    var releaseType: String
    /// For `SCHEDULED`: not before, on the hour.
    var releaseDate: Date?
    var isPhased: Bool
    /// `EncryptionAnswer`'s raw value; nil leaves the answer the build or
    /// Export Compliance has.
    var encryption: String?
    /// The events that go with the version; nil leaves the sheet's ticks.
    var eventIDs: [InAppEvent.ID]?

    var timing: ReleaseTiming {
        ReleaseTiming(releaseType: releaseType, earliestReleaseDate: releaseDate)
    }

    var encryptionAnswer: EncryptionAnswer? {
        encryption.flatMap(EncryptionAnswer.init(rawValue:))
    }

    /// The card's lines: "Build 1.4 (212)", "Release right after approval",
    /// "Phased release over 7 days", "Standard encryption only", "With
    /// “Mood Calendar”". `eventName` names an event by its id.
    func lines(version: String, eventName: (InAppEvent.ID) -> String) -> [String] {
        var lines = [String(localized: "Build \(version) (\(buildNumber))")]
        switch timing {
        case .afterApproval: lines.append(String(localized: "Release right after approval"))
        case .manual: lines.append(String(localized: "You release it yourself"))
        case let .scheduled(date): lines.append(String(localized: "Release on \(date.formatted(date: .abbreviated, time: .shortened))"))
        }
        lines.append(isPhased ? String(localized: "Phased Release over 7 days") : String(localized: "Everyone on the first day"))
        if let answer = encryptionAnswer { lines.append(answer.title) }
        if let eventIDs {
            lines.append(eventIDs.isEmpty
                ? String(localized: "No In-App Events")
                : String(localized: "With \(eventIDs.map { "“\(eventName($0))”" }.formatted(.list(type: .and)))"))
        }
        return lines
    }
}
