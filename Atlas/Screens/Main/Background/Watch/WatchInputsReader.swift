//
//  WatchInputsReader.swift
//  Atlas
//

import Foundation

/// Gathers what an hourly check already read about an app into
/// `WatchInputs`: crashes from the reports Atlas keeps, the version from
/// the release it follows, What's New and the version's answers from the
/// kept Store Page and App Information models, the events last read and
/// the reviews kept. Nothing here asks App Store Connect; only the project
/// folder's git history is read, and only when What's New is missing.
@MainActor
struct WatchInputsReader {
    let analytics: AnalyticsStore
    let releases: ReleaseStore
    let reviews: ReviewsStore
    let events: InAppEventsStore
    let launcher: ClaudeCodeLauncher
    let services: WorkspaceServices
    let keptModels: @MainActor (StoreApp.ID) -> AppSectionModels?

    func inputs(for app: StoreApp, now: Date) async -> WatchInputs {
        var inputs = WatchInputs(appID: app.id, appName: app.name, now: now)
        let kept = keptModels(app.id)
        let release = kept?.release
        inputs.stability = StabilityReport.make(analytics.reports(for: app.id), now: AnalyticsDay(analytics.now()))
        inputs.version = version(of: app.id, release: release)
        if let version = inputs.version, version.phase == .prepare, let release, release.status?.version.id == version.id {
            let rows = release.whatsNewRows
            if !rows.isEmpty {
                inputs.whatsNew = WatchInputs.WhatsNew(
                    languages: rows.count,
                    missing: rows.filter { $0.state == .missing }.map(\.locale.code),
                    suggested: rows.count { if case .suggested = $0.state { true } else { false } }
                )
            }
            inputs.blockers = blockers(of: app, release: release, appInformation: kept?.appInformation)
        }
        if inputs.whatsNew?.missing.isEmpty == false { inputs.commits = await commits(of: app.id, version: inputs.version?.versionString) }
        let storeLocales = release?.content?.locales.map(\.code)
        inputs.events = (events.lastRead(for: app.id) ?? release?.events ?? []).map { event in
            let suggested = Set(events.open(for: app.id, eventID: event.id).map(\.locale))
            return WatchEventFacts(event, storeLocales: storeLocales, suggestedLocales: suggested, now: now)
        }
        let archive = reviews.archive(for: app.id)
        inputs.reviews = archive.reviews
        inputs.reviewedVersion = archive.currentVersion
        inputs.themes = archive.themes
        return inputs
    }

    /// The version as the kept release model read it, else as last seen.
    private func version(of appID: StoreApp.ID, release: ReleaseViewModel?) -> WatchInputs.Version? {
        if let status = release?.status {
            return WatchInputs.Version(
                id: status.version.id, versionString: status.version.versionString, phase: status.phase, liveSince: liveSince(status.version.id)
            )
        }
        guard let snapshot = releases.snapshot(for: appID) else { return nil }
        return WatchInputs.Version(
            id: snapshot.versionID, versionString: snapshot.versionString, phase: snapshot.phase, liveSince: liveSince(snapshot.versionID)
        )
    }

    private func liveSince(_ versionID: String) -> Date? {
        releases.date(of: ReleasePhase.phased(day: 1, isPaused: false).key, versionID: versionID)
            ?? releases.date(of: ReleasePhase.live.key, versionID: versionID)
    }

    /// The answers the version being prepared still lacks, as the Submit
    /// sheet would say: the encryption answer for its build, App Review's
    /// contact, App Compliance and the age rating.
    private func blockers(of app: StoreApp, release: ReleaseViewModel, appInformation: AppInformationViewModel?) -> [WatchSubmissionBlocker] {
        guard let status = release.status else { return [] }
        var blockers: [WatchSubmissionBlocker] = []
        let build = ReleaseViewModel.defaultBuildID(in: status).flatMap { id in status.builds.first { $0.id == id } }
        let saved = EncryptionAnswer(services.appInformation.notes.notes(for: app.id).exportAnswers)
        if build != nil, EncryptionAnswer.known(saved: saved, build: build) == nil { blockers.append(.exportCompliance) }
        if !status.isReviewInformationComplete { blockers.append(.appReviewInformation) }
        if let appInformation, appInformation.complianceReport?.isUpToDate == false { blockers.append(.appCompliance) }
        if let appInformation, appInformation.isLoaded,
           AgeRatingQuestion.allCases.contains(where: { appInformation.suggestionValue(AppInformationSuggestionSlot.ageRating($0)).isEmpty })
        {
            blockers.append(.ageRating)
        }
        return blockers
    }

    /// The commits since the last release tag, from the project folder
    /// Atlas knows; nil without one.
    private func commits(of appID: StoreApp.ID, version: String?) async -> WatchInputs.Commits? {
        let excerpt = await launcher.readProjectFolder(for: appID) { ProjectFolderReader().excerpt(of: $0, version: version) }
        guard let excerpt, excerpt.problem == nil else { return nil }
        return WatchInputs.Commits(tag: excerpt.tag, count: excerpt.commits.count)
    }
}
