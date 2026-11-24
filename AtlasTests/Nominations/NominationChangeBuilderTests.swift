//
//  NominationChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Nominations' Review & Push rows: create, update, submit, archive and
/// delete each their own, grouped by nomination; a draft on this Mac's
/// Submit names it by placeholder and waits for its Create.
@Suite("Nominations · Review & Push rows")
struct NominationChangeBuilderTests {
    typealias Data = DebugNominationsData

    private let builder = NominationChangeBuilder(appID: Data.lumen)

    @Test func createPostsADraft() throws {
        let change = try builder.create(Data.draft, now: Data.now)
        #expect(change.id == "nomination.create.\(Data.draftID)")
        #expect(change.section == .nominations)
        #expect(change.group == "Nominations · Lumen 1.4: Weekly reflections")
        #expect(change.groupID == Data.draftID)
        #expect(change.title == "Create the draft")
        #expect(change.requests.map(\.method) == [.post])
        #expect(change.requests.map(\.path) == ["/v1/nominations"])
        #expect(change.source == .you)
    }

    @Test func updatePatchesAndNamesWhatChanged() throws {
        var edited = Data.winter
        edited.state = .draft
        edited.content.name = "Lumen 1.3: Winter Week"
        let change = try builder.update(edited, from: Data.winter.content, now: Data.now)
        #expect(change.id == "nomination.update.\(Data.winterID)")
        #expect(change.requests.map(\.path) == ["/v1/nominations/\(Data.winterID)"])
        #expect(change.requests.map(\.method) == [.patch])
        #expect(change.newValue == "Name")
    }

    @Test func aLocalDraftsSubmitWaitsForItsCreate() throws {
        let change = try builder.submit(Data.draft, now: Data.now)
        #expect(change.id == "nomination.submit.\(Data.draftID)")
        #expect(change.dependsOn == "nomination.create.\(Data.draftID)")
        let request = try #require(change.requests.first)
        let placeholder = try #require(NominationPlaceholder(in: request))
        #expect(placeholder.appID == Data.lumen)
        #expect(placeholder.localID == Data.draftID)
        #expect(placeholder.name == "Lumen 1.4: Weekly reflections")
        #expect(request.path == "/v1/nominations/\(placeholder.token)")
    }

    @Test func anAppStoreConnectDraftsSubmitNamesIt() throws {
        var draft = Data.winter
        draft.state = .draft
        let change = try builder.submit(draft, now: Data.now)
        #expect(change.dependsOn == nil)
        #expect(change.requests.map(\.path) == ["/v1/nominations/\(Data.winterID)"])
        #expect(change.requests.first?.bodyText?.contains(#""submitted":true"#) == true)
    }

    @Test func archiveAndDeleteAreTheirOwnRows() throws {
        let archive = try builder.archive(Data.winter, now: Data.now)
        #expect(archive.id == "nomination.archive.\(Data.winterID)")
        #expect(archive.requests.first?.bodyText?.contains(#""archived":true"#) == true)
        let delete = builder.delete(Data.winter, now: Data.now)
        #expect(delete.requests.map(\.method) == [.delete])
        #expect(delete.requests.first?.body == nil)
    }

    @Test func changeIDsParseBackAndGroupByNomination() throws {
        #expect(NominationChangeBuilder.parse("nomination.submit.local-a.b")?.kind == .submit)
        #expect(NominationChangeBuilder.parse("nomination.submit.local-a.b")?.nominationID == "local-a.b")
        #expect(NominationChangeBuilder.parse("event.new.x") == nil)
        let rows = try [builder.create(Data.draft), builder.submit(Data.draft), builder.archive(Data.winter)]
        let queued = builder.queued(for: Data.draftID, in: rows)
        #expect(Set(queued.keys) == [.create, .submit])
        #expect(NominationChangeBuilder(appID: Data.quiet).queued(for: Data.draftID, in: rows).isEmpty)
    }

    @Test func aPlaceholderSurvivesAnyName() {
        let placeholder = NominationPlaceholder(appID: "1", localID: "local-x", name: "Lumen: “Winter” / 2026 + more")
        let request = PushRequest(method: .patch, path: "/v1/nominations/\(placeholder.token)", body: nil)
        #expect(NominationPlaceholder(in: request)?.name == "Lumen: “Winter” / 2026 + more")
        #expect(NominationPlaceholder(in: PushRequest(method: .patch, path: "/v1/nominations/N1", body: nil)) == nil)
    }
}
