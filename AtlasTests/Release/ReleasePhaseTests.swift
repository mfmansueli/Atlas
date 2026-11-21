//
//  ReleasePhaseTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Where a version is on its way to the App Store, read from App Store
/// Connect's state and its phased release, and how the sidebar says it.
@Suite("Release · phase")
struct ReleasePhaseTests {
    @Test(arguments: [
        ("PREPARE_FOR_SUBMISSION", ReleasePhase.prepare),
        ("DEVELOPER_REJECTED", .prepare),
        ("WAITING_FOR_REVIEW", .waitingForReview),
        ("IN_REVIEW", .inReview),
        ("REJECTED", .rejected),
        ("METADATA_REJECTED", .rejected),
        ("INVALID_BINARY", .rejected),
        ("PENDING_DEVELOPER_RELEASE", .pendingDeveloperRelease),
        ("PENDING_APPLE_RELEASE", .pendingAppleRelease),
        ("PROCESSING_FOR_DISTRIBUTION", .pendingAppleRelease),
        ("READY_FOR_DISTRIBUTION", .live),
        ("READY_FOR_SALE", .live),
    ])
    func aStateBecomesAPhase(state: String, phase: ReleasePhase) {
        #expect(ReleasePhase(state: state, phased: nil) == phase)
    }

    @Test func aReleasedVersionFollowsItsPhasedRelease() {
        let active = PhasedRelease(id: "p", state: .active, day: 3)
        #expect(ReleasePhase(state: "READY_FOR_DISTRIBUTION", phased: active) == .phased(day: 3, isPaused: false))
        let paused = PhasedRelease(id: "p", state: .paused, day: 3)
        #expect(ReleasePhase(state: "READY_FOR_DISTRIBUTION", phased: paused) == .phased(day: 3, isPaused: true))
        // Apple counts from 0 until the first day is over.
        let first = PhasedRelease(id: "p", state: .active, day: 0)
        #expect(ReleasePhase(state: "READY_FOR_SALE", phased: first) == .phased(day: 1, isPaused: false))
        let complete = PhasedRelease(id: "p", state: .complete, day: 7)
        #expect(ReleasePhase(state: "READY_FOR_DISTRIBUTION", phased: complete) == .live)
        // Not started: the phased release waits for the version's release.
        let waiting = PhasedRelease(id: "p", state: .inactive, day: 0)
        #expect(ReleasePhase(state: "PENDING_DEVELOPER_RELEASE", phased: waiting) == .pendingDeveloperRelease)
    }

    @Test func onlyAVersionOnItsWayIsFollowedInTheBackground() {
        let inFlight: [ReleasePhase] = [.waitingForReview, .inReview, .pendingDeveloperRelease, .pendingAppleRelease, .phased(day: 2, isPaused: false)]
        // Bound first: a key path inside #expect reads as a throwing call.
        let followed = inFlight.map(\.isInFlight)
        let settled = [ReleasePhase.prepare, .rejected, .live].map(\.isInFlight)
        #expect(followed == [true, true, true, true, true])
        #expect(settled == [false, false, false])
    }

    @Test func thePhasedReleaseGrowsOverSevenDays() {
        #expect((1...7).map(PhasedRelease.percentage) == [1, 2, 5, 10, 20, 50, 100])
        #expect(PhasedRelease.percentage(day: 0) == 1)
        #expect(PhasedRelease.percentage(day: 12) == 100)
        #expect(ReleasePhase.phased(day: 3, isPaused: false).pillTitle == "Phased Release · Day 3 of 7")
        #expect(ReleasePhase.phased(day: 3, isPaused: true).pillTitle == "Phased Release Paused")
    }

    @Test func theSidebarSaysTheStatusAndWhatToDo() {
        let prepare = VersionStatusSummary(versionString: "1.4", phase: .prepare)
        #expect(prepare.line == "Version 1.4 · Not submitted yet")
        #expect(prepare.actionTitle == "Submit…")
        #expect(prepare.opensSubmit)
        #expect(prepare.accessibilityText == "Version 1.4, Not submitted yet")

        let pending = VersionStatusSummary(versionString: "1.4", phase: .pendingDeveloperRelease)
        #expect(pending.text == "Approved · ready to release")
        #expect(pending.actionTitle == "Release…")
        #expect(!pending.opensSubmit)
        #expect(pending.tone == .good)

        let rolling = VersionStatusSummary(versionString: "1.4", phase: .phased(day: 3, isPaused: false))
        #expect(rolling.text == "Rolling out · day 3 of 7")
        #expect(rolling.actionTitle == nil)
        #expect(VersionStatusSummary(versionString: "1.4", phase: .phased(day: 3, isPaused: true)).tone == .warning)
        #expect(VersionStatusSummary(versionString: "1.4", phase: .rejected).actionTitle == "Fix…")
        #expect(VersionStatusSummary(versionString: "1.4", phase: .waitingForReview).tone == .active)
    }

    @Test func beforeTheStatusIsReadTheSidebarSaysTheStorePagesState() {
        let summary = VersionStatusSummary(storePage: Self.storePage(version: "1.4", state: "Prepare for Submission"))
        #expect(summary?.line == "Version 1.4 · Prepare for Submission")
        #expect(summary?.actionTitle == nil)
        #expect(VersionStatusSummary(storePage: Self.storePage(version: nil, state: nil)) == nil)
        #expect(VersionStatusSummary(storePage: nil) == nil)
    }

    private static func storePage(version: String?, state: String?) -> StorePageSummary {
        StorePageSummary(
            versionString: version, versionState: state, hasEditableVersion: true, localeCount: 1, completeness: 1, missingCount: 0,
            machineTranslatedCount: 0, overLimitCount: 0
        )
    }

    @Test func releaseTimingReadsAndWritesApplesReleaseType() {
        let date = Date(timeIntervalSince1970: 1_794_830_400)
        #expect(ReleaseTiming(releaseType: "MANUAL", earliestReleaseDate: nil) == .manual)
        #expect(ReleaseTiming(releaseType: "AFTER_APPROVAL", earliestReleaseDate: nil) == .afterApproval)
        #expect(ReleaseTiming(releaseType: "SCHEDULED", earliestReleaseDate: date) == .scheduled(date))
        // Scheduled without a date can't be: Apple releases after approval.
        #expect(ReleaseTiming(releaseType: "SCHEDULED", earliestReleaseDate: nil) == .afterApproval)
        #expect(ReleaseTiming(releaseType: nil, earliestReleaseDate: nil) == .afterApproval)
        #expect(ReleaseTiming.scheduled(date).releaseType == "SCHEDULED")
        #expect(ReleaseTiming.scheduled(date).date == date)
        #expect(ReleaseTiming.manual.date == nil)
    }

    @Test func aScheduledReleaseIsOnTheHourAsAppleRequires() {
        var options = SubmissionOptions()
        options.timing = .scheduled
        options.releaseDate = Date(timeIntervalSince1970: 1_794_830_400 + 17 * 60 + 12)
        #expect(options.releaseTiming == .scheduled(Date(timeIntervalSince1970: 1_794_830_400)))
        options.timing = .manual
        #expect(options.releaseTiming == .manual)
    }

    @Test func theEncryptionAnswerIsKeptAsExportCompliance() {
        #expect(EncryptionAnswer(EncryptionAnswer.exempt.answers) == .exempt)
        #expect(EncryptionAnswer(EncryptionAnswer.noEncryption.answers) == .noEncryption)
        #expect(EncryptionAnswer(EncryptionAnswer.other.answers) == .other)
        #expect(EncryptionAnswer(nil) == nil)
        #expect(EncryptionAnswer(ExportComplianceAnswers()) == nil)
        #expect(!EncryptionAnswer.exempt.usesNonExemptEncryption)
        #expect(!EncryptionAnswer.noEncryption.usesNonExemptEncryption)
        #expect(EncryptionAnswer.other.usesNonExemptEncryption)
        // A build only says whether documentation is needed.
        #expect(EncryptionAnswer(buildUsesNonExemptEncryption: false) == .exempt)
        #expect(EncryptionAnswer(buildUsesNonExemptEncryption: true) == .other)
        #expect(EncryptionAnswer(buildUsesNonExemptEncryption: nil) == nil)
    }

    @Test func onlyAProcessedBuildThatHasntExpiredCanBeChosen() {
        #expect(ReleaseBuild(id: "b", number: "212", processing: .valid).isSelectable)
        #expect(!ReleaseBuild(id: "b", number: "213", processing: .processing).isSelectable)
        #expect(!ReleaseBuild(id: "b", number: "200", processing: .valid, isExpired: true).isSelectable)
        #expect(ReleaseBuild(id: "b", number: "213", processing: .processing).detail == "Apple is still processing it")
        #expect(ReleaseBuild(id: "b", number: "212", processing: .valid).title(version: "1.4") == "1.4 (212)")
    }

    @Test func anUploadedBuildShowsTheDayAndTime() throws {
        let uploaded = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 14, minute: 50)))
        let detail = ReleaseBuild(id: "b", number: "22", uploaded: uploaded, processing: .valid).detail
        #expect(detail.hasPrefix("Uploaded "))
        #expect(detail.contains(uploaded.formatted(.dateTime.day())))
        #expect(detail.contains(uploaded.formatted(.dateTime.hour().minute())))
    }
}
