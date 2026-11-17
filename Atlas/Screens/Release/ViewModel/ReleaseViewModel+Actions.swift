//
//  ReleaseViewModel+Actions.swift
//  Atlas
//

import Foundation

// The version card's buttons after submitting. Each is one write; the
// ones that can't be taken back ask first.
extension ReleaseViewModel {
    /// A button on the card: asks first when the action needs it.
    func request(_ action: ReleaseAction) {
        actionError = nil
        if action.confirmation(version: versionString) != nil {
            confirming = action
        } else {
            Task { await perform(action) }
        }
    }

    /// Pause Phased Release, or Resume.
    var pauseAction: ReleaseAction {
        if case .phased(_, true) = phase { return .resume }
        return .pause
    }

    var pauseTitle: String {
        pauseAction == .resume ? String(localized: "Resume Phased Release") : String(localized: "Pause Phased Release")
    }

    func perform(_ action: ReleaseAction) async {
        guard busyAction == nil, let status else { return }
        confirming = nil
        busyAction = action
        actionError = nil
        defer { busyAction = nil }
        do {
            let message = try await send(action, status: status)
            if let message { onMessage(message) }
            await load()
            onChanged()
        } catch {
            actionError = error.localizedDescription
        }
    }

    /// Sends the write; returns what to say once it went.
    private func send(_ action: ReleaseAction, status: ReleaseStatus) async throws -> String? {
        let version = status.version.versionString
        switch action {
        case .cancelSubmission:
            guard let submission = status.submission else { throw ReleaseActionError.nothingToAct }
            try await services.release.cancelSubmission(submission.id)
            return String(localized: "Submission canceled. \(version) is back to Prepare for Submission; nothing you edited is lost.")
        case .releaseNow:
            try await services.release.release(versionID: status.version.id)
            return status.phased == nil
                ? String(localized: "Releasing \(version). It’s on the App Store as soon as Apple has processed it.")
                : String(localized: "Releasing \(version). Phased release starts today: 1% of automatic updates on day 1.")
        case .pause, .resume:
            guard let phased = status.phased else { throw ReleaseActionError.nothingToAct }
            try await services.release.setPhasedRelease(phased.id, to: action == .pause ? .paused : .active)
            return nil
        case .releaseToEveryone:
            guard let phased = status.phased else { throw ReleaseActionError.nothingToAct }
            try await services.release.setPhasedRelease(phased.id, to: .complete)
            return String(localized: "\(version) now goes to everyone with automatic updates.")
        case .submitAgain:
            guard let submission = status.submission, submission.hasUnresolvedIssues else { throw ReleaseActionError.nothingToAct }
            try await services.release.resubmit(submission.id)
            return String(localized: "\(version) is submitted again.")
        }
    }

    /// Submit Again goes straight back to App Review when the submission
    /// is still open there; otherwise the Submit sheet starts a new one.
    var resubmitsDirectly: Bool {
        status?.submission?.hasUnresolvedIssues == true
    }

    /// Where Apple's message and the conversation with App Review are.
    var appStoreConnectURL: URL {
        URL(string: "https://appstoreconnect.apple.com/apps/\(app.id)/distribution") ?? URL(filePath: "/")
    }
}
