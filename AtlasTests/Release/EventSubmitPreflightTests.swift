//
//  EventSubmitPreflightTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Submit sheet's check of each ticked In-App Event before it goes
/// with the version (Alba 1.2.0: three events without a deep link made
/// App Store Connect refuse the whole submission), and what the sheet
/// says when App Store Connect still refuses.
@MainActor
@Suite("Release · In-App Events")
struct EventSubmitPreflightTests {
    typealias Events = DebugInAppEventsData

    private static let builds = [
        ReleaseBuild(id: "b213", number: "213", uploaded: nil, processing: .processing),
        ReleaseBuild(id: "b212", number: "212", uploaded: nil, processing: .valid),
        ReleaseBuild(id: "b211", number: "211", uploaded: nil, processing: .valid),
    ]

    private static let claimed = ProjectLinkClaimsState.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"]))

    private static func report(opens: Bool = true, build: String = "1.4 (212)", needsPremium: Bool = false) -> InAppEventDeepLinkReport {
        InAppEventDeepLinkReport(
            eventID: Events.moodID, deepLink: Events.moodDeepLink, opens: opens, shows: "The Mood Calendar", beforeStart: "Starts Nov 24",
            needsPremium: needsPremium, location: "Lumen/LumenApp.swift:48", build: build, testedInSimulator: true,
            problems: opens ? [] : ["LumenApp has no onOpenURL."], client: "Claude Code", date: .now
        )
    }

    private func preflight(
        _ event: InAppEvent = Events.mood, changes: [PendingChange] = [], state: ProjectLinkClaimsState = claimed,
        report: InAppEventDeepLinkReport? = nil, selected: String = "b212", pushesChanges: Bool = true
    ) -> EventSubmitPreflight {
        let builder = InAppEventChangeBuilder(appID: "lumen")
        let claim = InAppEventLinkClaim.of(builder.value(.deepLink, of: event, in: changes), in: state)
        let items = InAppEventReviewItem.items(
            for: event, changes: changes, builder: builder, claim: claim, appName: "Lumen Journal", now: DebugReleaseData.today
        )
        return EventSubmitPreflight.check(
            event, items: items, link: (claim, report), builds: (Self.builds.first { $0.id == selected }, Self.builds),
            pushesChanges: pushesChanges, appName: "Lumen Journal"
        )
    }

    // MARK: - Before submitting

    @Test func anEventWithoutADeepLinkBlocksSubmit() throws {
        var event = Events.mood
        event.deepLink = nil
        let result = preflight(event)
        #expect(result.blocks)
        #expect(result.missing.map(\.id) == ["deepLink"])
        #expect(result.missing[0].text == "No deep link: Open on the card has nowhere to go.")
        #expect(result.note == nil)

        // One waiting in Review & Push counts when the changes go first.
        let change = try #require(InAppEventChangeBuilder(appID: "lumen").detailChange(.deepLink, to: "lumen://mood", of: event, source: .you))
        #expect(!preflight(event, changes: [change]).blocks)
        #expect(preflight(event, changes: [change], pushesChanges: false).blocks)
        // An assistant's waits for Accept.
        var suggested = change
        suggested.awaitingAcceptance = "Accept it."
        #expect(preflight(event, changes: [suggested]).blocks)
    }

    @Test func aLinkTheProjectDoesntClaimBlocksWithMakeItWork() {
        let state = ProjectLinkClaimsState.read(folder: "/Lumen", claims: ProjectLinkClaims(targets: ["Lumen"]))
        let result = preflight(state: state)
        #expect(result.blocks)
        #expect(result.missing.map(\.text) == ["Lumen Journal doesn’t open lumen:// links yet"])
        #expect(result.offersFix)
    }

    @Test func aLinkNobodyCheckedIsACalmNote() {
        let result = preflight()
        #expect(!result.blocks)
        #expect(result.warnings.isEmpty)
        #expect(result.offersCheck)
        #expect(result.note == """
        Not checked: nobody has tried its deep link in Lumen Journal’s code yet. lumen:// is Lumen Journal’s, but Atlas can’t \
        tell whether it opens this event.
        """)
        // No project folder: still not a block.
        let noFolder = preflight(state: .noFolder)
        #expect(!noFolder.blocks)
        #expect(noFolder.note?.contains("choose Lumen Journal’s project folder") == true)
    }

    @Test func aCheckThatFailedWarnsButDoesntBlock() {
        let result = preflight(report: Self.report(opens: false))
        #expect(!result.blocks)
        #expect(result.warnings == ["Claude Code found that Lumen Journal doesn’t open its deep link yet. LumenApp has no onOpenURL."])
        #expect(result.offersFix)
        #expect(result.offersCheck)
    }

    @Test func anOlderBuildThanTheCheckedOneWarnsAndOffersIt() {
        let result = preflight(report: Self.report(), selected: "b211")
        #expect(!result.blocks)
        #expect(result.warnings == ["Build 211 is older than the build where Lumen Journal opens these links (212)."])
        #expect(result.newerBuild?.id == "b212")
        // The checked build or a newer one: nothing to say.
        #expect(preflight(report: Self.report(), selected: "b212").warnings.isEmpty)
        // Checked in a build not uploaded yet: the warning, no build to pick.
        let notUploaded = preflight(report: Self.report(build: "1.4 (220)"), selected: "b212")
        #expect(notUploaded.warnings.count == 1)
        #expect(notUploaded.newerBuild == nil)
    }

    @Test func aFreeEventLandingOnPremiumIsWarned() {
        let result = preflight(report: Self.report(needsPremium: true))
        #expect(result.warnings == ["Its deep link lands on Premium, but the event is free. App Review rejects that."])
    }

    // MARK: - When App Store Connect refuses

    private static let plan = SubmissionPlan(
        appID: "lumen", versionID: "v14", platform: "IOS", buildID: "b212", attachedBuildID: "b212", usesNonExemptEncryption: nil,
        timing: .manual, isPhased: true, eventIDs: [Events.gratitudeID, Events.moodID]
    )

    @Test func aRefusedEventIsNamedWithWhatTheDraftHolds() {
        let failure = SubmissionFailure(
            step: .addEvent(Events.moodID), message: "You must provide a value for the attribute 'deepLink' with this request",
            submissionID: "sub1", hasVersion: true, eventIDs: [Events.gratitudeID], underlying: nil
        )
        let text = ReleaseViewModel.failureText(failure, events: Events.events, plan: Self.plan, versionString: "1.4")
        #expect(text == """
        App Store Connect didn’t add the In-App Event “Mood Calendar” to the submission. You must provide a value for the attribute 'deepLink' with this request
        Nothing went to App Review. App Store Connect keeps the review submission as a draft with 1.4 and “Gratitude Week”. Fix what it names, \
        or untick the event, and Submit again: Atlas sends that same draft, without the events you untick.
        """)
    }

    @Test func aRefusedSendNamesTheEventsBehindEachReason() throws {
        let body = Foundation.Data(#"""
        {"errors":[{"status":"409","code":"STATE_ERROR.ENTITY_STATE_INVALID","title":"x",
        "detail":"This resource cannot be reviewed, please check associated errors to see why.",
        "meta":{"associatedErrors":{
          "/v1/appEvents/event-mood":[{"code":"ENTITY_ERROR.ATTRIBUTE.REQUIRED","status":"409","title":"x",
             "detail":"You must provide a value for the attribute 'deepLink' with this request"}],
          "/v1/appEvents/event-gratitude":[{"code":"ENTITY_ERROR.ATTRIBUTE.REQUIRED","status":"409","title":"x",
             "detail":"You must provide a value for the attribute 'deepLink' with this request"}]
        }}}]}
        """#.utf8)
        let error = AppStoreConnectError(statusCode: 409, body: body)
        let message = try #require(error.errorDescription)
        #expect(message.contains("'deepLink' with this request (In-App Event event-mood)"))
        #expect(message.contains("'deepLink' with this request (In-App Event event-gratitude)"))

        let failure = SubmissionFailure(
            step: .send, message: message, submissionID: "sub1", hasVersion: true, eventIDs: Self.plan.eventIDs, underlying: error
        )
        let text = ReleaseViewModel.failureText(failure, events: Events.events, plan: Self.plan, versionString: "1.4")
        #expect(text.hasPrefix("App Store Connect didn’t send the submission to App Review."))
        #expect(text.contains("'deepLink' with this request (“Mood Calendar”)"))
        #expect(text.contains("'deepLink' with this request (“Gratitude Week”)"))
        #expect(text.contains("as a draft with 1.4, “Gratitude Week”"))
        #expect(text.contains("“Mood Calendar”. Fix what it names"))
    }

    /// App Store Connect said "deepLink" without naming the event: the
    /// sheet names the ticked ones without one.
    @Test func aReasonWithoutTheEventNamesTheOnesWithoutADeepLink() {
        var mood = Events.mood
        mood.deepLink = nil
        var gratitude = Events.gratitude
        gratitude.deepLink = "lumen://gratitude"
        let failure = SubmissionFailure(
            step: .send, message: "You must provide a value for the attribute 'deepLink' with this request", submissionID: "sub1",
            hasVersion: true, eventIDs: [Events.moodID], underlying: nil
        )
        let text = ReleaseViewModel.failureText(failure, events: [mood, gratitude], plan: Self.plan, versionString: "1.4")
        #expect(text.contains("Without a deep link: “Mood Calendar”."))
    }

    @Test func aRefusalBeforeAnyDraftSaysNothingWent() {
        let failure = SubmissionFailure(step: .release, message: "The version can’t change now.", submissionID: nil, hasVersion: false, eventIDs: [])
        let text = ReleaseViewModel.failureText(failure, events: [], plan: Self.plan, versionString: "1.4")
        #expect(text == "The version can’t change now.\nNothing went to App Review.")
    }
}
#endif
