//
//  PhasedReleaseAttributes.swift
//  Atlas
//

import Foundation

/// An `appStoreVersionPhasedReleases` resource.
struct PhasedReleaseAttributes: Decodable, Sendable {
    /// `INACTIVE`, `ACTIVE`, `PAUSED` or `COMPLETE`.
    var phasedReleaseState: String?
    var startDate: String?
    var totalPauseDuration: Int?
    var currentDayNumber: Int?
}
