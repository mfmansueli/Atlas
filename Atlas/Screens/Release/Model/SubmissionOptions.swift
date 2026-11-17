//
//  SubmissionOptions.swift
//  Atlas
//

import Foundation

/// What the person chose in the Submit sheet.
struct SubmissionOptions: Hashable, Sendable {
    var buildID: ReleaseBuild.ID?
    var timing = ReleaseTiming.Kind.manual
    /// For "Release on a date".
    var releaseDate = Date.now
    var isPhased = true
    var encryption: EncryptionAnswer?
    /// "Push N changes with this submission".
    var pushesChanges = true
    /// The In-App Events that go with the version.
    var eventIDs: Set<InAppEvent.ID> = []

    /// App Store Connect takes a release time on the hour.
    static func onTheHour(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
    }

    var releaseTiming: ReleaseTiming {
        switch timing {
        case .afterApproval: .afterApproval
        case .manual: .manual
        case .scheduled: .scheduled(Self.onTheHour(releaseDate))
        }
    }
}
