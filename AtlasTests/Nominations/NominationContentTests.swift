//
//  NominationContentTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What a nomination needs before it can go to App Store Connect, and the
/// links Apple takes only in Materials.
@Suite("Nominations · content checks")
struct NominationContentTests {
    typealias Data = DebugNominationsData

    @Test func aReadyDraftHasNoProblems() {
        #expect(Data.draft.content.problems(now: Data.now).isEmpty)
        #expect(Data.draft.content.daysUntilStart(now: Data.now) == 9)
    }

    @Test func anEmptyDraftSaysWhatToAdd() {
        let content = NominationContent(appIDs: [Data.lumen])
        #expect(content.missing == ["a type", "a name", "a description", "a start date"])
        #expect(content.problems(now: Data.now) == ["Add a type, a name, a description, and a start date."])
    }

    @Test func aPassedStartIsRefused() {
        var content = Data.draft.content
        content.publishStart = Data.day(2026, 11, 20)
        #expect(content.startHasPassed(now: Data.now))
        #expect(content.problems(now: Data.now) == ["The start date has passed. Pick one that hasn’t."])
        content.publishStart = Data.day(2026, 11, 24, hour: 7)
        #expect(!content.startHasPassed(now: Data.now))
    }

    @Test func anEndBeforeTheStartIsRefused() {
        var content = Data.draft.content
        content.publishEnd = Data.day(2026, 12, 1)
        #expect(content.problems(now: Data.now) == ["The end date is before the start date."])
    }

    @Test func materialsMustBeFullLinks() {
        #expect(NominationLink.isValid("https://lumen.app/press"))
        #expect(!NominationLink.isValid("lumen.app/press"))
        #expect(!NominationLink.isValid("https://localhost"))
        var content = Data.draft.content
        content.materials = ["lumen.app/press"]
        #expect(content.problems(now: Data.now) == ["“lumen.app/press” isn’t a full link. Use one that starts with https://."])
    }

    @Test func linksAreFoundInTheDescription() {
        #expect(NominationLink.links(in: "Watch the film: https://lumen.app/weekly today.") == ["https://lumen.app/weekly"])
        #expect(NominationLink.links(in: Data.draft.content.description).isEmpty)
        #expect(NominationLink.host(of: "https://lumen.app/press-kit") == "lumen.app")
    }

    @Test func changedFieldsFollowTheNominationsOrder() {
        var content = Data.draft.content
        content.notes = "New notes"
        content.name = "Lumen 1.4"
        #expect(content.changedFields(from: Data.draft.content) == [.name, .notes])
        #expect(Data.draft.content.changedFields(from: Data.draft.content).isEmpty)
    }
}
