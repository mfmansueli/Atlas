//
//  WatchSubmissionBlocker.swift
//  Atlas
//

import Foundation

/// An answer the version being prepared still lacks before it can go to App
/// Review, as Atlas last read it.
enum WatchSubmissionBlocker: String, CaseIterable, Codable, Hashable, Sendable {
    /// Export Compliance: no encryption answer for the build.
    case exportCompliance
    /// App Review's contact (or demo account) isn't filled in.
    case appReviewInformation
    /// App Compliance (trader status, licences) needs the person.
    case appCompliance
    /// An Age Rating question has no answer.
    case ageRating

    /// For the assistant's prompt, in English.
    var summary: String {
        switch self {
        case .exportCompliance: "the encryption question in Export Compliance"
        case .appReviewInformation: "App Review's contact information"
        case .appCompliance: "App Compliance"
        case .ageRating: "an Age Rating question"
        }
    }
}
