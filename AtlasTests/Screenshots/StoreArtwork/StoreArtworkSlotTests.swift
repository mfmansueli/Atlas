//
//  StoreArtworkSlotTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Which placeholder, image and pill each header and search tile shows
/// (board 78).
@Suite("Store artwork slot")
struct StoreArtworkSlotTests {
    private typealias Fixtures = StoreArtworkFixtures

    @Test func noHeaderShowsTheDashedBoxAndNoSearchShowsScreenshotsOneToThree() {
        let header = StoreArtworkSlot(place: .header, locale: "fr-FR", live: nil, extras: nil)
        let search = StoreArtworkSlot(place: .search, locale: "fr-FR", live: nil, extras: nil)
        #expect(header.state == .none)
        #expect(header.content == .noHeader)
        #expect(search.content == .searchShots)
        #expect(header.storeContent == nil)
        #expect(search.storeContent == nil)
        #expect(header.buttonTitle == "Add")
        #expect(search.state.title(for: .search) == "Uses screenshots 1–3")
    }

    @Test func liveArtworkIsLiveWithTheOutlinePill() {
        let live = Fixtures.live(.header)
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: live, extras: nil)
        #expect(slot.state == .live)
        #expect(slot.content == .live(live))
        #expect(slot.state.title(for: .header) == "Live")
        #expect(slot.state.pillStyle == .outline)
        #expect(!slot.state.isNotPushed)
        #expect(slot.buttonTitle == "Edit")
    }

    @Test func aFileWhereNothingIsLiveIsNewNotPushed() {
        let file = Fixtures.handFile(.search)
        let slot = StoreArtworkSlot(place: .search, locale: "de-DE", live: nil, extras: Fixtures.extras([file]))
        #expect(slot.state == .new)
        #expect(slot.state.title(for: .search) == "New · not pushed")
        #expect(slot.state.pillStyle == .accent)
        #expect(slot.state.isNotPushed, "The blue outline")
        #expect(slot.content == .file(file))
        #expect(slot.storeContent == .file(file))
    }

    @Test func aFileOverLiveArtworkIsReplaced() {
        let file = Fixtures.handFile(.header)
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: Fixtures.live(.header), extras: Fixtures.extras([file]))
        #expect(slot.state == .replaced)
        #expect(slot.state.title(for: .header) == "Replaced · not pushed")
        #expect(slot.content == .file(file))
    }

    @Test func aDeletionDimsWhatsLiveAndLeavesTheStore() {
        let live = Fixtures.live(.header)
        var extras = Fixtures.extras()
        extras.markRemoval(.header, locale: "de-DE", at: Fixtures.date)
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: live, extras: extras)
        #expect(slot.state == .willBeDeleted)
        #expect(slot.state.title(for: .header) == "Will be deleted")
        #expect(slot.state.pillStyle == .danger)
        #expect(slot.content == .live(live))
        #expect(slot.storeContent == nil, "The preview shows the page without it")
        #expect(!slot.state.isNotPushed)
    }

    @Test func anotherLanguagesFileDoesntCount() {
        let slot = StoreArtworkSlot(place: .header, locale: "fr-FR", live: nil, extras: Fixtures.extras([Fixtures.handFile(.header, "de-DE")]))
        #expect(slot.state == .none)
    }

    @Test func aPushedFileIsNoLongerWaiting() {
        let file = Fixtures.handFile(.header)
        var extras = Fixtures.extras([file])
        extras.notePushed(file.id, fileID: file.fileID)
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: Fixtures.live(.header), extras: extras)
        #expect(slot.state == .live)
    }

    @Test func aWideFileShowsInBothPlacesButTheOwnKindWins() {
        var extras = Fixtures.extras()
        extras.artwork = [Fixtures.madeFile(.header, fileID: "header"), ExtrasArtworkFile(
            kind: .wide, locale: "de-DE", fileID: "wide", headline: "", fits: true, byteCount: 1, checks: []
        )]
        #expect(extras.pendingArtwork(.header, locale: "de-DE")?.fileID == "header")
        #expect(extras.pendingArtwork(.search, locale: "de-DE")?.fileID == "wide")
    }

    @Test func theAccessibilityLabelSaysPlaceLanguageAndState() {
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: Fixtures.live(.header), extras: nil)
        #expect(slot.accessibilityLabel(localeName: "German") == "Header, German, Live")
        #expect(slot.id == "header-de-DE")
    }
}
#endif
