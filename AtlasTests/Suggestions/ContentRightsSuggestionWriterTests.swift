//
//  ContentRightsSuggestionWriterTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Content rights as a suggestion field: stored by App Store Connect's id,
/// the app's rather than a version's, and written through
/// `AppInformationSuggestionWriter` like the page's Yes/No: a Yes waits for
/// "I have the rights to use it" unless it was already given. Lumen's
/// sample says No.
@Suite("Content rights suggestion field and writer")
struct ContentRightsSuggestionWriterTests {
    private let content = DebugAppInformationContent.lumen(versionID: nil)
    private let claude = ChangeSource.assistant(client: "Claude Code")
    private let field = AppInformationSuggestionField.contentRights
    private let yesID = ContentRights.usesThirdPartyContent.rawValue
    private let noID = ContentRights.doesNotUseThirdPartyContent.rawValue

    private func builder(_ content: AppInformationContent) -> AppInformationChangeBuilder {
        AppInformationChangeBuilder(appID: DebugFixtures.AppID.lumen, ids: content.ids, versionString: content.version?.versionString)
    }

    private func values(_ content: AppInformationContent? = nil, changes: [PendingChange] = []) -> AppInformationSuggestionWriter.Values {
        let content = content ?? self.content
        let builder = builder(content)
        return AppInformationSuggestionWriter.Values(
            content: content,
            general: builder.general(content.general, with: changes),
            review: content.review,
            builder: builder
        )
    }

    @Test func itsAPickedGeneralFieldOfTheApp() {
        #expect(field.page == .general)
        #expect(AppInformationSuggestionField.fields(on: .general).contains(field))
        #expect(field.isPicked)
        #expect(!field.isVersionLevel)
        #expect(field.reviewField == nil)
        #expect(field.displayValue(yesID) == "Yes")
        #expect(field.displayValue(noID) == "No")
        #expect(field.value(general: content.general, review: nil) == noID)
        #expect(field.value(general: GeneralValues(), review: nil) == "")
    }

    @Test func assistantsValuesAreNormalizedToTheID() {
        #expect(field.normalized("yes") == yesID)
        #expect(field.normalized(" Yes ") == yesID)
        #expect(field.normalized("TRUE") == yesID)
        #expect(field.normalized("uses_third_party_content") == yesID)
        #expect(field.normalized("No") == noID)
        #expect(field.normalized("false") == noID)
        #expect(field.normalized(noID) == noID)
        #expect(field.normalized("maybe") == nil)
        #expect(field.normalized("") == nil)
    }

    @Test func aYesQueuesTheAppsChangeWaitingForTheRights() throws {
        let written = try #require(AppInformationSuggestionWriter.change(field, to: yesID, in: values(), source: claude))
        #expect(written.id == builder(content).changeID(.general, AppInformationChangeBuilder.GeneralKey.contentRights))
        let change = try #require(written.change)
        #expect(change.source == claude)
        #expect(change.newValue == "Yes")
        #expect(change.blockedReason != nil)
        #expect(change.requests.first?.path == "/v1/apps/\(DebugFixtures.AppID.lumen)")
    }

    @Test func backToAppStoreConnectsValueQueuesNothing() throws {
        let written = try #require(AppInformationSuggestionWriter.change(field, to: noID, in: values(), source: claude))
        #expect(written.change == nil)
        #expect(AppInformationSuggestionWriter.change(field, to: "maybe", in: values(), source: claude) == nil)
    }

    @Test func rightsAlreadyConfirmedStayConfirmed() throws {
        var live = content
        live.general.contentRights = .usesThirdPartyContent
        let toNo = try #require(AppInformationSuggestionWriter.change(field, to: noID, in: values(live), source: .you)?.change)
        // The person's No queued, then the assistant's Yes: back to App
        // Store Connect's Yes, which needs no confirming.
        let backToYes = try #require(AppInformationSuggestionWriter.change(field, to: yesID, in: values(live, changes: [toNo]), source: claude))
        #expect(backToYes.change == nil)

        let confirmed = try #require(builder(content).contentRightsChange(
            from: .doesNotUseThirdPartyContent, to: .usesThirdPartyContent, rightsConfirmed: true
        ))
        let general = builder(content).general(content.general, with: [confirmed])
        #expect(general.rightsConfirmed)
        let written = try #require(AppInformationSuggestionWriter.change(field, to: yesID, in: values(changes: [confirmed]), source: claude))
        #expect(written.change?.blockedReason == nil)
    }

    @Test func aVersionInReviewDoesntLockIt() throws {
        var inReview = content
        inReview.version = StorePageVersion(id: "v2", listingVersion: ListingVersion("1.4", state: .waitingForReview), platform: "IOS")
        #expect(!inReview.isVersionEditable)
        let written = try #require(AppInformationSuggestionWriter.change(field, to: yesID, in: values(inReview), source: claude))
        #expect(written.change != nil)
        #expect(AppInformationSuggestionWriter.change(.copyright, to: "© 2027", in: values(inReview), source: claude) == nil)
    }
}
#endif
