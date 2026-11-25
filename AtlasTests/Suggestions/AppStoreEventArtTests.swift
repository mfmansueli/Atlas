//
//  AppStoreEventArtTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The App Store preview's event card plays the file Atlas uploaded it
/// from when it's still here, else shows App Store Connect's poster, else
/// the gradient.
@Suite("AppStoreEventArt")
struct AppStoreEventArtTests {
    private let poster = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Video211/poster.png/640x360bb.jpg")
    private var card: InAppEventMedia {
        InAppEventMedia(kind: .card, isVideo: true, imageURL: poster, fileName: "gratitude-week-2026-card-en-us.mov", fileSize: 8_652_567)
    }

    private func stored(_ name: String, size: Int, id: String = "ea-3fa07964fc") -> InAppEventArtworkStoredFile {
        InAppEventArtworkStoredFile(fileID: id, url: URL(fileURLWithPath: "/tmp/EventArtwork/6825428345/\(id)/\(name)"), fileName: name, fileSize: size)
    }

    @Test func theUploadedFilePlays() {
        let files = [stored("other.png", size: 10), stored("gratitude-week-2026-card-en-us.mov", size: 8_652_567)]
        #expect(AppStoreEventArt.source(for: card, stored: files) == .file(
            path: "/tmp/EventArtwork/6825428345/ea-3fa07964fc/gratitude-week-2026-card-en-us.mov", isVideo: true
        ))
    }

    @Test func aFileOfAnotherSizeIsntIt() throws {
        let files = [stored("gratitude-week-2026-card-en-us.mov", size: 1)]
        #expect(try AppStoreEventArt.source(for: card, stored: files) == .remote(#require(poster)))
    }

    /// Not on this Mac: App Store Connect's clip plays over its poster.
    @Test func elseTheClipAppStoreConnectStreams() throws {
        var streamed = card
        let video = try #require(URL(string: "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/P1_default.m3u8"))
        streamed.videoURL = video
        #expect(AppStoreEventArt.source(for: streamed, stored: []) == .remoteVideo(poster: poster, video: video))
        // Still processing: no poster yet, the clip still plays.
        streamed.imageURL = nil
        #expect(AppStoreEventArt.poster(of: streamed) == .remoteVideo(poster: nil, video: video))
        // An image never streams.
        var image = streamed
        image.isVideo = false
        #expect(AppStoreEventArt.poster(of: image) == .none)
    }

    @Test func withoutAPosterOrCardTheGradient() {
        var bare = card
        bare.imageURL = nil
        #expect(AppStoreEventArt.source(for: bare, stored: []) == .none)
        #expect(AppStoreEventArt.source(for: nil, stored: []) == .none)
    }

    @Test func noAppNoFileLookup() async throws {
        let event = try #require(AppStoreLiveEvent(Self.event(card: card), locale: .englishUS, now: Self.now))
        #expect(try await AppStoreEventArt.source(for: event) == .remote(#require(poster)))
    }

    @Test func theStorefrontsOwnCardElseThePrimarys() throws {
        let german = InAppEventMedia(kind: .card, imageURL: URL(string: "https://example.com/de.jpg"))
        let event = Self.event(card: card, germanCard: german)
        #expect(try #require(AppStoreLiveEvent(event, locale: .german, now: Self.now)).card == german)
        #expect(try #require(AppStoreLiveEvent(event, locale: .japanese, now: Self.now)).card == card)
    }

    private static let now = ISO8601DateFormatter().date(from: "2026-11-27T12:00:00Z") ?? .distantPast

    private static func event(card: InAppEventMedia, germanCard: InAppEventMedia? = nil) -> InAppEvent {
        let date = { (text: String) in ISO8601DateFormatter().date(from: text) }
        var english = InAppEventLocalization(id: "en", locale: "en-US", name: "7 Days of Gratitude", shortDescription: "A grateful phrase every morning")
        english.media = [card]
        var german = InAppEventLocalization(id: "de", locale: "de-DE", name: "7 Tage Dankbarkeit")
        german.media = germanCard.map { [$0] } ?? []
        return InAppEvent(
            id: "gratitude", referenceName: "Gratitude Week 2026", badge: .challenge, state: .published, primaryLocale: "en-US",
            schedules: [InAppEventSchedule(
                publishStart: date("2026-11-22T00:00:00Z"), eventStart: date("2026-11-26T00:00:00Z"), eventEnd: date("2026-12-02T23:59:00Z")
            )],
            localizations: [english, german]
        )
    }
}
