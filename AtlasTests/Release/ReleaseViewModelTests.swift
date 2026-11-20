//
//  ReleaseViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Submit for Review and release, over the sample account's Lumen Journal
/// 1.4: what the card and the sheet say is missing, the one plan a
/// submission sends, and each button after submitting.
@MainActor
@Suite("ReleaseViewModel")
struct ReleaseViewModelTests {
    typealias Data = DebugReleaseData

    private let release = FakeReleaseServices()
    private let queue = ChangeQueue()
    private let store = DebugReleaseData.store(.prepare)
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]

    /// Lumen 1.4 in `phase`; What's New is missing in Italian unless
    /// `isWhatsNewComplete`.
    private func makeModel(
        _ phase: DebugReleasePhase = .prepare, isWhatsNewComplete: Bool = false, encryption: EncryptionAnswer? = nil,
        suggestions: FieldSuggestionStore = FieldSuggestionStore(), inAppEvents: [InAppEvent]? = nil
    ) async -> (model: ReleaseViewModel, services: WorkspaceServices) {
        var services = ReleaseDebugScenes.services(phase, encryption: encryption)
        services.inAppEvents = DebugInAppEventsServices(events: inAppEvents)
        if isWhatsNewComplete {
            var storePage = DebugStorePageServices()
            storePage.whatsNew = Data.whatsNew.merging([Data.missingLocale: Data.suggestedWhatsNew]) { _, new in new }
            services.storePage = storePage
        }
        release.status = Data.status(phase)
        services.release = release
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let model = ReleaseViewModel(app: app, services: services, store: store, queue: queue, suggestions: suggestions, push: push)
        model.now = { Data.today }
        model.eventsStore = events
        model.linkClaims = claims
        await model.load()
        return (model, services)
    }

    private let events = InAppEventsStore()
    private let claims = ProjectLinkClaimsCenter()

    // MARK: - Before submitting

    @Test func theCardSaysWhatGoesToAppReviewAndWhatIsMissing() async {
        let (model, _) = await makeModel(suggestions: Data.suggestions())
        #expect(model.phase == .prepare)
        #expect(model.cardTitle == "Lumen Journal 1.4 is almost ready for App Review")
        let checks = model.checks
        #expect(checks.map(\.kind) == [.build, .whatsNew, .changes, .event])
        #expect(checks[0].title == "Build 1.4 (212)")
        #expect(checks[0].isOK)
        #expect(checks[1].title == "What’s New in 9 of 10 languages")
        #expect(checks[1].detail == "Italian is missing; a suggestion is waiting")
        #expect(!checks[1].isOK)
        #expect(checks[2].title == "Store Page, Screenshots and Pricing are pushed")
        #expect(checks[3].title == "In-App Event “Mood Calendar”")
        #expect(checks[3].eventID == DebugInAppEventsData.moodID)
        #expect(model.summary?.line == "Version 1.4 · Not submitted yet")
    }

    @Test func theSheetSaysExactlyWhatToDoBeforeSubmitting() async {
        let (model, _) = await makeModel()
        #expect(model.submitTitle == "Submit Lumen Journal 1.4 for App Review")
        #expect(model.whatsNewTitle == "What’s New · 9 of 10 languages")
        #expect(model.whatsNewRows.first { $0.isMissing }?.locale == .italian)
        #expect(model.needsEncryptionAnswer)
        #expect(model.blockers == ["add What’s New in Italian", "answer the encryption question"])
        #expect(model.footerText == "To submit, add What’s New in Italian and answer the encryption question.")
        #expect(!model.canSubmit)
        #expect(await !model.submit())
        #expect(release.plans.isEmpty)
        // The newest build that's ready is chosen: 213 is still processing.
        #expect(model.selectedBuild?.number == "212")
    }

    @Test func anAcceptedWhatsNewCountsOnceItGoesWithTheSubmission() async {
        queue.upsert(ReleaseDebugScenes.acceptedWhatsNew)
        let (model, _) = await makeModel(encryption: .exempt)
        #expect(model.whatsNewRows.first { $0.locale == .italian }?.state == .notPushed)
        #expect(model.blockers.isEmpty)
        #expect(model.submitButtonTitle == "Push and Submit for Review")
        #expect(model.checks.first { $0.kind == .changes }?.title == "1 change not pushed yet")
        model.options.pushesChanges = false
        #expect(model.blockers == ["push the changes (What’s New is among them)"])
        #expect(model.submitButtonTitle == "Submit for Review")
    }

    @Test func aReleaseDateHasToBeAhead() async {
        let (model, _) = await makeModel(isWhatsNewComplete: true, encryption: .exempt)
        #expect(model.canSubmit)
        model.options.timing = .scheduled
        model.options.releaseDate = Data.today.addingTimeInterval(-3600)
        #expect(model.blockers == ["pick a release date that’s still ahead"])
        model.options.releaseDate = Data.today.addingTimeInterval(3 * 86400)
        #expect(model.canSubmit)
    }

    @Test func withoutAProcessedBuildThereIsNothingToSubmit() async {
        let (model, _) = await makeModel(isWhatsNewComplete: true, encryption: .exempt)
        var status = Data.status(.prepare)
        status.builds = status.builds.filter { $0.processing == .processing }
        model.load(status: status, content: model.content, events: [])
        #expect(model.blockers == ["upload a build from Xcode"])
        #expect(model.checks[0].title == "No build yet")
        #expect(model.checks[0].detail == "Apple is still processing the one you uploaded")
    }

    // MARK: - Submitting

    @Test func submittingSendsOnePlanAndKeepsTheEncryptionAnswer() async throws {
        let (model, services) = await makeModel(isWhatsNewComplete: true)
        model.options.encryption = .exempt
        var messages: [String] = []
        model.onMessage = { messages.append($0) }
        #expect(model.footerText == "App Review usually takes about a day. You can cancel until review starts.")
        #expect(await model.submit())

        let plan = try #require(release.plans.first)
        #expect(plan.appID == app.id)
        #expect(plan.versionID == Data.versionID)
        #expect(plan.buildID == "build-212")
        #expect(plan.attachedBuildID == "build-212")
        // The build has no answer yet: this one is written on it.
        #expect(plan.usesNonExemptEncryption == false)
        #expect(plan.timing == .manual)
        #expect(plan.isPhased)
        #expect(plan.eventIDs == [DebugInAppEventsData.moodID])
        #expect(messages == ["Lumen Journal 1.4 is submitted. App Review usually takes about a day."])
        #expect(services.appInformation.notes.notes(for: app.id).exportAnswers == EncryptionAnswer.exempt.answers)
        #expect(store.eventIDs(for: app.id) == [DebugInAppEventsData.moodID])
        #expect(model.submitError == nil)
    }

    @Test func anEventThatIsntTickedStaysBehind() async throws {
        let (model, _) = await makeModel(isWhatsNewComplete: true, encryption: .exempt)
        model.setEvent(DebugInAppEventsData.moodID, goesWithVersion: false)
        #expect(store.eventIDs(for: app.id).isEmpty)
        #expect(model.checks.map(\.kind) == [.build, .whatsNew, .changes])
        model.options.isPhased = false
        model.options.timing = .afterApproval
        #expect(await model.submit())
        let plan = try #require(release.plans.first)
        #expect(plan.eventIDs.isEmpty)
        #expect(!plan.isPhased)
        #expect(plan.timing == .afterApproval)
        // The answer comes from Export Compliance; the build doesn't carry it yet, so it's written on it.
        #expect(plan.usesNonExemptEncryption == false)
    }

    /// Alba 1.2.0: a ticked event without a deep link made App Store
    /// Connect refuse the submission. Now Submit waits until it's fixed or
    /// unticked, and every draft that could go is offered.
    @Test func aTickedEventAppReviewWouldRefuseBlocksSubmit() async {
        var mood = DebugInAppEventsData.mood
        mood.deepLink = nil
        let (model, _) = await makeModel(
            isWhatsNewComplete: true, encryption: .exempt, inAppEvents: [DebugInAppEventsData.winter, mood, DebugInAppEventsData.gratitude]
        )
        // The Winter draft isn't ready, but it's offered: ticking it says what it needs.
        #expect(model.offeredEvents.map(\.id) == [DebugInAppEventsData.winterID, DebugInAppEventsData.moodID])
        #expect(model.tickedEvents.map(\.id) == [DebugInAppEventsData.moodID])
        #expect(model.preflight(of: mood).missing.map(\.id) == ["deepLink"])
        #expect(model.blockers == ["fix or untick “Mood Calendar”"])
        #expect(model.footerText == "To submit, fix or untick “Mood Calendar”.")
        #expect(!model.canSubmit)

        model.setEvent(DebugInAppEventsData.winterID, goesWithVersion: true)
        #expect(model.blockers == ["fix or untick 2 In-App Events"])
        model.setEvent(DebugInAppEventsData.winterID, goesWithVersion: false)
        model.setEvent(DebugInAppEventsData.moodID, goesWithVersion: false)
        #expect(model.blockers.isEmpty)
        #expect(await model.submit())
        #expect(release.plans.first?.eventIDs.isEmpty == true)
    }

    /// Lumen's project doesn't declare lumen://: blocked. Once it does and
    /// the link was checked in build 212, picking 211 warns, and Use Build
    /// 212 picks it.
    @Test func theDeepLinkCheckWarnsAboutAnOlderBuild() async throws {
        let (model, _) = await makeModel(isWhatsNewComplete: true, encryption: .exempt)
        let mood = try #require(model.events.first { $0.id == DebugInAppEventsData.moodID })
        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(targets: ["Lumen"])), for: app.id)
        #expect(model.preflight(of: mood).missing.map(\.text) == ["Lumen Journal doesn’t open lumen:// links yet"])
        #expect(!model.canSubmit)

        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"])), for: app.id)
        #expect(model.preflight(of: mood).note?.hasPrefix("Not checked:") == true)
        #expect(model.canSubmit)
        events.setDeepLinkReport(InAppEventDeepLinkReport(
            eventID: mood.id, deepLink: DebugInAppEventsData.moodDeepLink, opens: true, shows: "The Mood Calendar", beforeStart: "Starts Nov 24",
            needsPremium: false, location: "Lumen/LumenApp.swift:48", build: "1.4 (212)", testedInSimulator: true, problems: [],
            client: "Claude Code", date: Data.today
        ), for: app.id)
        model.options.buildID = "build-211"
        let preflight = model.preflight(of: mood)
        #expect(preflight.warnings == ["Build 211 is older than the build where Lumen Journal opens these links (212)."])
        let newer = try #require(preflight.newerBuild)
        model.useBuild(newer)
        #expect(model.options.buildID == "build-212")
        #expect(model.preflight(of: mood).warnings.isEmpty)
        #expect(model.canSubmit)
    }

    @Test func aRefusedSubmissionSaysWhyAndChangesNothing() async {
        let (model, services) = await makeModel(isWhatsNewComplete: true)
        model.options.encryption = .noEncryption
        release.refuses = true
        #expect(await !model.submit())
        #expect(model.submitError != nil)
        #expect(!model.isSubmitting)
        #expect(services.appInformation.notes.notes(for: app.id).exportAnswers == nil)
    }

    /// SimProps: the first Submit made the phased release and stopped; the
    /// second was refused because the sheet still said there was none.
    /// Now the sheet reads the version again and keeps the person's answers.
    @Test func aSubmissionThatStoppedHalfwayReadsTheVersionAgain() async {
        let (model, _) = await makeModel(isWhatsNewComplete: true)
        model.options.encryption = .noEncryption
        model.options.timing = .afterApproval
        release.refuses = true
        var halfway = Data.status(.prepare)
        halfway.phased = PhasedRelease(id: "ph-made", state: .inactive, day: 0, startDate: nil)
        release.status = halfway

        #expect(await !model.submit())
        #expect(model.submitError != nil)
        #expect(model.status?.phased?.id == "ph-made")
        #expect(model.options.timing == .afterApproval)
        #expect(model.options.encryption == .noEncryption)
    }

    // MARK: - After submitting

    @Test func cancelingAsksFirstThenTakesTheSubmissionBack() async {
        let (model, _) = await makeModel(.waiting)
        var messages: [String] = []
        model.onMessage = { messages.append($0) }
        #expect(model.cardTitle == "1.4 is waiting for App Review")
        model.request(.cancelSubmission)
        #expect(model.confirming == .cancelSubmission)
        #expect(release.actions.isEmpty)
        await model.perform(.cancelSubmission)
        #expect(release.actions == ["cancel \(Data.submissionID)"])
        #expect(model.confirming == nil)
        #expect(messages == ["Submission canceled. 1.4 is back to Prepare for Submission; nothing you edited is lost."])
    }

    @Test func anApprovedVersionIsReleasedIntoItsPhasedRelease() async {
        let (model, _) = await makeModel(.pending)
        var messages: [String] = []
        model.onMessage = { messages.append($0) }
        #expect(model.cardTitle == "1.4 is approved and waiting for you")
        #expect(model.summary?.actionTitle == "Release…")
        await model.perform(.releaseNow)
        #expect(release.actions == ["release \(Data.versionID)"])
        #expect(messages == ["Releasing 1.4. Phased release starts today: 1% of automatic updates on day 1."])
    }

    @Test func aPhasedReleasePausesResumesAndEndsEarly() async {
        let (model, _) = await makeModel(.phased)
        #expect(model.cardTitle == "1.4 is rolling out")
        #expect(model.cardSubtitle.hasPrefix("5% of people with automatic updates have 1.4 so far."))
        #expect(model.pauseAction == .pause)
        #expect(model.pauseTitle == "Pause Phased Release")
        await model.perform(.pause)
        release.status = Data.status(.paused)
        await model.load()
        #expect(model.pauseAction == .resume)
        #expect(model.pauseTitle == "Resume Phased Release")
        #expect(model.cardTitle == "The rollout of 1.4 is paused")
        await model.perform(.resume)
        model.request(.releaseToEveryone)
        #expect(model.confirming == .releaseToEveryone)
        await model.perform(.releaseToEveryone)
        #expect(release.actions == ["phased \(Data.phasedID) PAUSED", "phased \(Data.phasedID) ACTIVE", "phased \(Data.phasedID) COMPLETE"])
    }

    @Test func aRejectedSubmissionIsSubmittedAgainAsItIs() async {
        let (model, _) = await makeModel(.rejected)
        #expect(model.cardTitle == "App Review sent 1.4 back")
        #expect(model.resubmitsDirectly)
        await model.perform(.submitAgain)
        #expect(release.actions == ["resubmit \(Data.submissionID)"])
    }

    @Test func aWriteAppleRefusesSaysSoAndAnActionWithNothingToActOnDoesNothing() async {
        let (model, _) = await makeModel(.waiting)
        release.refuses = true
        await model.perform(.cancelSubmission)
        #expect(model.actionError != nil)
        #expect(model.busyAction == nil)
        release.refuses = false
        // Nothing is rolling out.
        await model.perform(.pause)
        #expect(model.actionError != nil)
        #expect(release.actions.isEmpty)
    }

    // MARK: - Steps

    @Test func theStepsShowWhereTheVersionIs() async {
        let (waiting, _) = await makeModel(.waiting)
        #expect(waiting.steps.map(\.title) == ["Submitted", "Waiting for Review", "In Review", "Approved", "On the App Store"])
        #expect(waiting.steps.map(\.state) == [.done, .current, .upcoming, .upcoming, .upcoming])
        #expect(waiting.steps[1].detail == "Usually about a day")
        #expect(waiting.steps[4].detail == "")

        let (rejected, _) = await makeModel(.rejected)
        #expect(rejected.steps[2].title == "Rejected")
        #expect(rejected.steps.map(\.state) == [.done, .done, .rejected, .upcoming, .upcoming])
        // A step that hasn't happened has no date.
        #expect(rejected.steps[3].detail == "")
        #expect(rejected.steps[4].detail == "")

        let (phased, _) = await makeModel(.phased)
        #expect(phased.steps.map(\.state) == [.done, .done, .done, .done, .current])
        #expect(phased.steps[4].detail == "Day 3 of 7")
        let (prepared, _) = await makeModel(.prepare)
        #expect(prepared.steps.map(\.state) == [.upcoming, .upcoming, .upcoming, .upcoming, .upcoming])
    }

    // MARK: - Telling

    @Test func aVersionThatMovedIsAnnouncedOnce() async {
        let (model, _) = await makeModel(.waiting)
        var messages: [String] = []
        model.onMessage = { messages.append($0) }
        release.status = Data.status(.review)
        await model.load()
        await model.load()
        #expect(messages == ["App Review is looking at Lumen Journal 1.4."])
        release.status = Data.status(.pending)
        await model.load()
        #expect(messages.last == "Lumen Journal 1.4 is approved and waiting for you to release it.")
    }

    @Test func everyMoveHasItsSentenceButTheOnesThePersonMade() {
        func said(_ phase: ReleasePhase) -> String? {
            ReleaseViewModel.announcement(phase, version: "1.4", appName: "Lumen")
        }
        #expect(said(.prepare) == nil)
        #expect(said(.waitingForReview) == nil)
        #expect(said(.rejected) == "App Review sent Lumen 1.4 back. Its message is in App Store Connect.")
        #expect(said(.phased(day: 1, isPaused: false)) == "Lumen 1.4 is on the App Store, rolling out over 7 days.")
        #expect(said(.live) == "Lumen 1.4 is on the App Store for everyone.")
        let submitted = ReleaseViewModel.submittedText("Lumen 1.4", pushed: 4)
        #expect(submitted == "Lumen 1.4 is submitted, with 4 pushed changes. App Review usually takes about a day.")
    }

    @Test func beforeReadingTheSidebarSaysWhatWasSeenLast() async {
        _ = await makeModel(.phased)
        let services = WorkspaceServices.debug
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let fresh = ReleaseViewModel(app: app, services: services, store: store, queue: queue, suggestions: FieldSuggestionStore(), push: push)
        #expect(fresh.status == nil)
        #expect(fresh.summary?.line == "Version 1.4 · Rolling out · day 3 of 7")
    }
}
#endif
