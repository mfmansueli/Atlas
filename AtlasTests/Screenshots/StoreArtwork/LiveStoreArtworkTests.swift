//
//  LiveStoreArtworkTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Reading what a page shows now: placements with their images.
@Suite("Live store artwork")
struct LiveStoreArtworkTests {
    private typealias Fixtures = StoreArtworkFixtures

    @Test func theIPhoneGroupWinsWhenAPlaceHasSeveral() {
        let pad = Fixtures.live(.header, group: "IPAD")
        let phone = Fixtures.live(.header, group: "IPHONE")
        let artwork = LiveStoreArtwork(images: [pad, phone, Fixtures.live(.search, group: nil)])
        #expect(artwork.header == phone)
        #expect(artwork.search?.placementGroup == nil)
        #expect(LiveStoreArtwork(images: [pad]).header == pad)
    }

    @Test func theURLFillsWidthHeightAndPNG() {
        let url = Fixtures.live(.search).url(width: 600)
        #expect(url?.absoluteString == "https://is1.mzstatic.com/search/600x400bb.png")
    }

    @Test func thePathAsksForBothTypesWithTheirImagesAndVideos() {
        let path = AssetLibraryRequests.artworkPlacementsPath(localizationID: "loc-1")
        #expect(path.hasPrefix("/v1/appStoreVersionLocalizations/loc-1/placements?"))
        #expect(path.contains("PRODUCT_PAGE_HEADER_ASSET%2CAPP_STORE_SEARCH_RESULTS_ASSET"))
        #expect(path.contains("include=image,video"), "A header pushed with its motion loop is a video placement")
    }

    /// The bug on Alba: a header made with a motion loop is pushed as a
    /// video, and a read that took only images showed "No header".
    @Test func aMovingHeaderReadsAsLiveWithItsPosterFrame() throws {
        let json = """
        {"data":[
          {"type":"appAssetLibraryPlacements","id":"p1","attributes":{"mediaType":"VIDEO","placementType":"PRODUCT_PAGE_HEADER_ASSET",
           "placementGroup":"IPHONE"},
           "relationships":{"video":{"data":{"type":"appAssetLibraryVideos","id":"v1"}}}},
          {"type":"appAssetLibraryPlacements","id":"p2","attributes":{"mediaType":"VIDEO","placementType":"APP_STORE_SEARCH_RESULTS_ASSET"},
           "relationships":{"video":{"data":{"type":"appAssetLibraryVideos","id":"v2"}}}}
        ],
        "included":[
          {"type":"appAssetLibraryVideos","id":"v1","attributes":{"state":"COMPLETE","videoAsset":"https://a/v1.mp4",
           "previewFrameImage":{"image":{"templateUrl":"https://a/poster/{w}x{h}.{f}","width":3840,"height":1646}}}},
          {"type":"appAssetLibraryVideos","id":"v2","attributes":{"state":"COMPLETE","previewFrameImage":{"image":{"templateUrl":"https://a/s/{w}x{h}.{f}"}}}}
        ],
        "links":{"self":"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/loc-1/placements"}}
        """
        let images = try AssetLibraryRequests.placedArtwork(in: Data(json.utf8))
        let artwork = LiveStoreArtwork(images: images)
        #expect(artwork.header?.placementID == "p1")
        #expect(artwork.header?.templateURL == "https://a/poster/{w}x{h}.{f}")
        #expect(artwork.header?.pixelSize == PixelSize(width: 3840, height: 1646))
        #expect(artwork.search?.placementID == "p2")
    }

    @Test func aMovingHeaderStillProcessingIsLeftOut() throws {
        let json = """
        {"data":[
          {"type":"appAssetLibraryPlacements","id":"p1","attributes":{"placementType":"PRODUCT_PAGE_HEADER_ASSET"},
           "relationships":{"video":{"data":{"type":"appAssetLibraryVideos","id":"v1"}}}}
        ],
        "included":[{"type":"appAssetLibraryVideos","id":"v1","attributes":{"state":"UPLOAD_COMPLETE"}}]}
        """
        #expect(try AssetLibraryRequests.placedArtwork(in: Data(json.utf8)).isEmpty, "No poster frame yet: nothing to draw")
    }

    @Test func anImageAndAVideoWithTheSameIDAreNotMixedUp() throws {
        let json = """
        {"data":[
          {"type":"appAssetLibraryPlacements","id":"p1","attributes":{"placementType":"PRODUCT_PAGE_HEADER_ASSET"},
           "relationships":{"video":{"data":{"type":"appAssetLibraryVideos","id":"same"}}}}
        ],
        "included":[
          {"type":"appAssetLibraryImages","id":"same","attributes":{"imageAsset":{"templateUrl":"https://a/image/{w}x{h}.{f}"}}},
          {"type":"appAssetLibraryVideos","id":"same","attributes":{"previewFrameImage":{"image":{"templateUrl":"https://a/poster/{w}x{h}.{f}"}}}}
        ]}
        """
        let images = try AssetLibraryRequests.placedArtwork(in: Data(json.utf8))
        #expect(images.map(\.templateURL) == ["https://a/poster/{w}x{h}.{f}"])
    }

    @Test func placementsReadWithTheirImagesAndTheRestLeftOut() throws {
        let json = """
        {"data":[
          {"type":"assetLibraryPlacements","id":"p1","attributes":{"placementType":"PRODUCT_PAGE_HEADER_ASSET","placementGroup":"IPHONE"},
           "relationships":{"image":{"data":{"type":"assetLibraryImages","id":"i1"}}}},
          {"type":"assetLibraryPlacements","id":"p2","attributes":{"placementType":"APP_STORE_SEARCH_RESULTS_ASSET"},
           "relationships":{"image":{"data":{"type":"assetLibraryImages","id":"i2"}}}},
          {"type":"assetLibraryPlacements","id":"p3","attributes":{"placementType":"APP_STORE_SEARCH_RESULTS_ASSET"},
           "relationships":{"image":{"data":null}}}
        ],
        "included":[
          {"type":"assetLibraryImages","id":"i1","attributes":{"imageAsset":{"templateUrl":"https://a/{w}x{h}.{f}","width":3840,"height":1646}}},
          {"type":"assetLibraryImages","id":"i2","attributes":{}}
        ]}
        """
        let images = try AssetLibraryRequests.placedArtwork(in: Data(json.utf8))
        #expect(images.count == 1, "No image, or no URL yet: left out")
        #expect(images.first?.placementID == "p1")
        #expect(images.first?.place == .header)
        #expect(images.first?.pixelSize == PixelSize(width: 3840, height: 1646))
        #expect(images.first?.templateURL == "https://a/{w}x{h}.{f}")
    }

    @Test func aBodyThatIsntJSONIsAnUnexpectedPayload() {
        #expect(throws: AppStoreConnectError.self) {
            try AssetLibraryRequests.placedArtwork(in: Data("nope".utf8))
        }
    }
}
#endif
