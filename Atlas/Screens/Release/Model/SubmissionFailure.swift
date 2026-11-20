//
//  SubmissionFailure.swift
//  Atlas
//

import Foundation

/// Where a Submit stopped, and what it left in App Store Connect: the
/// step App Store Connect refused (attaching the build, adding an In-App
/// Event to the review submission, sending it…), and the review submission
/// it made or reused, which stays a draft (`READY_FOR_REVIEW`) with what
/// was added. Submit again sends that same draft.
struct SubmissionFailure: LocalizedError, Sendable {
    enum Step: Hashable, Sendable {
        case attachBuild
        case encryption
        case release
        case phasedRelease
        case createSubmission
        case addVersion
        case addEvent(String)
        case removeEvent(String)
        case send
    }

    var step: Step
    /// App Store Connect's words.
    var message: String
    /// The draft submission left behind; nil when it stopped before one.
    var submissionID: String?
    /// Whether that draft carries the version.
    var hasVersion = false
    /// The events in that draft.
    var eventIDs: [String] = []
    var underlying: AppStoreConnectError?

    var errorDescription: String? { message }

    /// Runs one step, turning a refusal into a failure at that step.
    static func at<T>(
        _ step: Step, submissionID: String? = nil, hasVersion: Bool = false, eventIDs: [String] = [],
        isolation _: isolated (any Actor)? = #isolation,
        _ work: () async throws -> T
    ) async throws -> T {
        do {
            return try await work()
        } catch {
            throw SubmissionFailure(
                step: step, message: error.localizedDescription, submissionID: submissionID, hasVersion: hasVersion, eventIDs: eventIDs,
                underlying: error as? AppStoreConnectError
            )
        }
    }
}
