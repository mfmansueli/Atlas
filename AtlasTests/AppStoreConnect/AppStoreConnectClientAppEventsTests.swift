//
//  AppStoreConnectClientAppEventsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reading In-App Events with their languages and images from App Store
/// Connect.
@MainActor
@Suite("App Store Connect · In-App Events")
struct AppStoreConnectClientAppEventsTests {
    private static let events = CannedHTTPResponse(body: #"""
    {"data":[
      {"type":"appEvents","id":"e-old",
       "attributes":{
         "referenceName":"Gratitude Week","badge":"SPECIAL_EVENT","eventState":"PAST","primaryLocale":"en-US",
         "priority":"NORMAL","purpose":"APPROPRIATE_FOR_ALL_USERS","territorySchedules":[],
         "archivedTerritorySchedules":[{
           "territories":["USA","DEU"],"publishStart":"2026-10-24T07:00:00Z",
           "eventStart":"2026-10-31T07:00:00Z","eventEnd":"2026-11-07T08:00:00Z"}]},
       "relationships":{"localizations":{"data":[{"type":"appEventLocalizations","id":"l-old"}]}}},
      {"type":"appEvents","id":"e-new",
       "attributes":{
         "referenceName":"Winter Reflection 2026","badge":"CHALLENGE","eventState":"DRAFT","primaryLocale":"en-US",
         "priority":"HIGH",
         "territorySchedules":[{
           "territories":["USA"],"publishStart":"2026-11-24T08:00:00Z",
           "eventStart":"2026-12-01T08:00:00Z","eventEnd":"2026-12-31T08:00:00Z"}]},
       "relationships":{"localizations":{"data":[
         {"type":"appEventLocalizations","id":"l-en"},{"type":"appEventLocalizations","id":"l-de"}]}}}
    ],
    "included":[
      {"type":"appEventLocalizations","id":"l-old",
       "attributes":{"locale":"en-US","name":"Gratitude Week","shortDescription":"Seven days","longDescription":"One thing a day."}},
      {"type":"appEventLocalizations","id":"l-en",
       "attributes":{
         "locale":"en-US","name":"Winter Reflection Challenge","shortDescription":"31 prompts",
         "longDescription":"Three lines a day."}},
      {"type":"appEventLocalizations","id":"l-de",
       "attributes":{"locale":"de-DE","name":"Winter-Reflexion","shortDescription":null,"longDescription":null}}
    ]}
    """#)

    private static let screenshots = CannedHTTPResponse(body: #"""
    {"data":[{"type":"appEventScreenshots","id":"s1","attributes":{
      "appEventAssetType":"EVENT_CARD","fileName":"winter-card-en-us.png","fileSize":482113,
      "assetDeliveryState":{"state":"COMPLETE","errors":[],"warnings":[]},
      "imageAsset":{"templateUrl":"https://example.com/card/{w}x{h}.{f}","width":1920,"height":1080}}}]}
    """#)
    private static let clips = CannedHTTPResponse(body: #"""
    {"data":[{"type":"appEventVideoClips","id":"c1","attributes":{
      "appEventAssetType":"EVENT_DETAILS_PAGE","fileName":"winter-details-en-us.mov","fileSize":9120334,
      "previewFrameTimeCode":"00:00:02:00","videoDeliveryState":{"state":"COMPLETE","errors":[]},
      "previewFrameImage":{"image":{"templateUrl":"https://example.com/details/{w}x{h}.{f}","width":1080,"height":1920},
        "state":{"state":"COMPLETE"}},
      "previewImage":{"templateUrl":"https://example.com/old/{w}x{h}.{f}","width":1080,"height":1920}}}]}
    """#)
    private static let germanCard = CannedHTTPResponse(body: #"""
    {"data":[{"type":"appEventScreenshots","id":"s2","attributes":{
      "appEventAssetType":"EVENT_CARD","fileName":"winter-card-de.png","fileSize":1203,
      "assetDeliveryState":{"state":"FAILED","errors":[{"code":"IMAGE_TOOL_FAILURE","description":"The image couldn't be read."}]},
      "imageAsset":{"templateUrl":"https://example.com/de/{w}x{h}.{f}","width":3840,"height":2160}}}]}
    """#)
    private static let none = CannedHTTPResponse(body: #"{"data":[]}"#)

    private func client(_ transport: FakeHTTPTransport) -> AppStoreConnectClient {
        AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
    }

    @Test func eventsAreAskedForWithTheirLanguages() async throws {
        let transport = FakeHTTPTransport([Self.events])
        let pages = try await client(transport).appEvents(appID: "42")
        #expect(pages.count == 1)
        let request = try #require(transport.requests.first)
        #expect(request.url?.path() == "/v1/apps/42/appEvents")
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        #expect(items.contains(URLQueryItem(name: "include", value: "localizations")))
        #expect(items.contains(URLQueryItem(name: "limit[localizations]", value: "50")))
        #expect(pages[0].data[1].localizationIDs == ["l-en", "l-de"])
    }

    /// The events, then each language's images and videos, read in
    /// parallel: every language of the draft, only the primary one of the
    /// event that's over.
    private static func eventTransport() -> FakeHTTPTransport {
        FakeHTTPTransport([events], routes: [
            ("appEventLocalizations/l-en/appEventScreenshots", screenshots),
            ("appEventLocalizations/l-en/appEventVideoClips", clips),
            ("appEventLocalizations/l-de/appEventScreenshots", germanCard),
            ("appEventLocalizations/", none),
        ])
    }

    @Test func anEventIsReadWithItsLanguagesScheduleAndImages() async throws {
        let transport = Self.eventTransport()
        let services = LiveInAppEventsServices(client: client(transport))
        let app = StoreApp(id: "42", name: "Lumen", bundleID: "dev.lumen", sku: nil, primaryLocale: "en-US")
        let events = try await services.events(for: app)
        // What can still change comes first; what's over goes last.
        #expect(events.map(\.id) == ["e-new", "e-old"])

        let winter = events[0]
        #expect(winter.referenceName == "Winter Reflection 2026")
        #expect(winter.badge == .challenge)
        #expect(winter.state == .draft)
        #expect(winter.priority == .high)
        #expect(winter.localizations.map(\.locale) == ["en-US", "de-DE"])
        #expect(winter.localization("de-DE")?.isComplete == false)
        #expect(winter.schedule?.eventStart == AppStoreConnectDate.date("2026-12-01T08:00:00Z"))
        #expect(winter.media(.card)?.sizeText == "1920 × 1080")
        #expect(winter.media(.card)?.imageURL?.absoluteString == "https://example.com/card/640x360.jpg")
        #expect(winter.media(.details)?.isVideo == true)
        // A video's poster frame comes from previewFrameImage, not the
        // deprecated previewImage.
        #expect(winter.media(.details)?.imageURL?.absoluteString == "https://example.com/details/640x1137.jpg")
        // Alba 1.2.0's drafts read like this one: no deep link, no purpose,
        // and App Store Connect refuses to send them to App Review.
        #expect(winter.deepLink == nil)
        #expect(winter.purpose == nil)
        // Before its card shows (Nov 24): its dates are fine.
        #expect(try winter.missing(now: #require(AppStoreConnectDate.date("2026-11-19T12:00:00Z"))) == [
            "add a deep link", "choose its purpose", "write every language",
        ])
        // The files as they were uploaded, and Apple's processing.
        let card = try #require(winter.media(.card))
        #expect(card.fileName == "winter-card-en-us.png")
        #expect(card.fileSize == 482_113)
        #expect(card.state == "COMPLETE")
        #expect(card.stateErrors.isEmpty)
        #expect(card.previewFrameTimeCode == nil)
        let details = try #require(winter.media(.details))
        #expect(details.fileName == "winter-details-en-us.mov")
        #expect(details.fileSize == 9_120_334)
        #expect(details.previewFrameTimeCode == "00:00:02:00")
        #expect(details.state == "COMPLETE")
        // German has its own card; it shows the English details page.
        #expect(winter.localization("de-DE")?.media == [
            InAppEventMedia(
                kind: .card, width: 3840, height: 2160, imageURL: URL(string: "https://example.com/de/640x360.jpg"), fileName: "winter-card-de.png",
                fileSize: 1203, state: "FAILED", stateErrors: ["The image couldn't be read."]
            ),
        ])

        // An ended event's dates are in its archived schedule.
        let gratitude = events[1]
        #expect(gratitude.state == .past)
        #expect(gratitude.schedule?.territories == ["USA", "DEU"])
        #expect(gratitude.schedule?.eventEnd == AppStoreConnectDate.date("2026-11-07T08:00:00Z"))

        // Every language of the draft and the past event's primary one,
        // each its images then its videos.
        let mediaPaths = Set(transport.requests.dropFirst().compactMap { $0.url?.path() })
        #expect(mediaPaths == [
            "/v1/appEventLocalizations/l-old/appEventScreenshots", "/v1/appEventLocalizations/l-old/appEventVideoClips",
            "/v1/appEventLocalizations/l-en/appEventScreenshots", "/v1/appEventLocalizations/l-en/appEventVideoClips",
            "/v1/appEventLocalizations/l-de/appEventScreenshots", "/v1/appEventLocalizations/l-de/appEventVideoClips",
        ])
        let clipFields = transport.requests.first { $0.url?.path().hasSuffix("l-en/appEventVideoClips") == true }
            .flatMap { $0.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } } ?? []
        #expect(clipFields.contains(URLQueryItem(
            name: "fields[appEventVideoClips]",
            value: "appEventAssetType,previewFrameImage,previewImage,fileName,fileSize,previewFrameTimeCode,videoDeliveryState,videoUrl"
        )))
        let imageFields = transport.requests.first { $0.url?.path().hasSuffix("l-en/appEventScreenshots") == true }
            .flatMap { $0.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } } ?? []
        #expect(imageFields.contains(URLQueryItem(
            name: "fields[appEventScreenshots]", value: "appEventAssetType,imageAsset,fileName,fileSize,assetDeliveryState"
        )))
    }

    /// Media read before Apple returned the file's name and size, or
    /// without processing, still read.
    @Test func mediaWithoutTheFileFieldsStillRead() throws {
        let attributes = try JSONDecoder().decode(AppEventMediaAttributes.self, from: Data(#"""
        {"appEventAssetType":"EVENT_CARD","imageAsset":{"templateUrl":"https://example.com/{w}x{h}.{f}","width":1920,"height":1080},
         "assetDeliveryState":{"errors":null}}
        """#.utf8))
        let media = try #require(LiveInAppEventsServices.media(attributes, isVideo: false))
        #expect(media.fileName == nil)
        #expect(media.fileSize == nil)
        #expect(media.state == nil)
        #expect(media.sizeText == "1920 × 1080")
    }

    /// A clip keeps where it streams from, so it plays where its card
    /// shows; an image never has one.
    @Test func aClipKeepsWhereItStreamsFrom() throws {
        let attributes = try JSONDecoder().decode(AppEventMediaAttributes.self, from: Data(#"""
        {"appEventAssetType":"EVENT_CARD","fileName":"card.mov","videoDeliveryState":{"state":"COMPLETE"},
         "videoUrl":"https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/P1_default.m3u8",
         "previewFrameImage":{"image":{"templateUrl":"https://example.com/{w}x{h}.{f}","width":1920,"height":1080}}}
        """#.utf8))
        let clip = try #require(LiveInAppEventsServices.media(attributes, isVideo: true))
        #expect(clip.videoURL?.absoluteString == "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/P1_default.m3u8")
        #expect(clip.imageURL?.absoluteString == "https://example.com/640x360.jpg")
        let video = try #require(clip.videoURL)
        #expect(InAppEventArtSource(remote: clip) == .remoteVideo(poster: clip.imageURL, video: video))
        #expect(LiveInAppEventsServices.media(attributes, isVideo: false)?.videoURL == nil)
    }

    @Test func aFailedReadOfTheEventsIsAnError() async {
        let failure = CannedHTTPResponse(statusCode: 500, body: #"{"errors":[{"status":"500","code":"X","title":"Oops","detail":"Later."}]}"#)
        let transport = FakeHTTPTransport([failure])
        let services = LiveInAppEventsServices(client: client(transport))
        let app = StoreApp(id: "42", name: "Lumen", bundleID: "dev.lumen", sku: nil, primaryLocale: "en-US")
        await #expect(throws: (any Error).self) {
            _ = try await services.events(for: app)
        }
    }
}
