//
//  FirstRunTourTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("FirstRunTour")
struct FirstRunTourTests {
    /// Defaults of their own, never the person's.
    private func freshDefaults() -> UserDefaults {
        let name = "FirstRunTourTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsOnTheFirstTipAndRemembersItWasShown() {
        let defaults = freshDefaults()
        let tour = FirstRunTour(defaults: defaults)
        #expect(!tour.isShowing)
        #expect(!tour.hasBeenShown)
        tour.start()
        #expect(tour.step == .apps)
        #expect(tour.hasBeenShown)
        #expect(defaults.bool(forKey: FirstRunTour.shownKey))
    }

    @Test func nextWalksTheFiveTipsAndDoneEnds() {
        let tour = FirstRunTour()
        tour.start()
        var seen: [TourStep] = []
        while let step = tour.step {
            seen.append(step)
            tour.next()
        }
        #expect(seen == [.apps, .sections, .autopilot, .reviewPush, .settings])
        #expect(!tour.isShowing)
    }

    @Test(arguments: [TourStep.apps, .sections, .autopilot, .reviewPush])
    func skipTheTourEndsItOnAnyTipButTheLast(step: TourStep) {
        let tour = FirstRunTour(step: step)
        #expect(tour.alternative() == .ended)
        #expect(tour.step == nil)
    }

    @Test func theLastTipsSecondButtonConnectsAnAssistant() {
        let tour = FirstRunTour(step: .settings)
        #expect(tour.alternative() == .connectsAssistant)
        #expect(tour.step == nil)
    }

    @Test func closeEndsTheTour() {
        let tour = FirstRunTour(step: .autopilot)
        tour.close()
        #expect(tour.step == nil)
    }

    @Test func aTipThatClosesByItselfEndsTheTourOnlyWhileItShows() {
        let tour = FirstRunTour(step: .apps)
        tour.next()
        // The first tip's popover goes away after Next: the second stays.
        tour.tipClosed(.apps)
        #expect(tour.step == .sections)
        // A click elsewhere closes the tip showing.
        tour.tipClosed(.sections)
        #expect(tour.step == nil)
    }

    @Test func showTheTourStartsAgainFromTheFirstTip() {
        let tour = FirstRunTour(step: .reviewPush)
        tour.close()
        tour.start()
        #expect(tour.step == .apps)
    }

    @Test func theFirstRunStartsTheTourOncePerMac() {
        let defaults = freshDefaults()
        let first = FirstRunTour(defaults: defaults)
        #expect(first.dueStep(startsOnFirstRun: true) == .apps)
        first.start()
        first.close()
        #expect(first.dueStep(startsOnFirstRun: true) == nil)
        // A later window, or a later launch, on the same Mac.
        let later = FirstRunTour(defaults: defaults)
        #expect(later.hasBeenShown)
        #expect(later.dueStep(startsOnFirstRun: true) == nil)
    }

    @Test func windowsThatDontStartItByThemselvesNeverDo() {
        let tour = FirstRunTour(defaults: freshDefaults())
        #expect(tour.dueStep(startsOnFirstRun: false) == nil)
    }

    @Test func aScenesTipWinsAndNothingStartsWhileATipShows() {
        let tour = FirstRunTour()
        tour.start()
        tour.close()
        #expect(tour.dueStep(opening: .reviewPush, startsOnFirstRun: false) == .reviewPush)
        tour.start(at: .autopilot)
        #expect(tour.step == .autopilot)
        #expect(tour.dueStep(opening: .reviewPush, startsOnFirstRun: true) == nil)
    }

    @Test func withoutDefaultsItRemembersInMemoryOnly() {
        let tour = FirstRunTour()
        #expect(tour.dueStep(startsOnFirstRun: true) == .apps)
        tour.start()
        #expect(tour.hasBeenShown)
        #expect(!FirstRunTour().hasBeenShown)
    }
}
