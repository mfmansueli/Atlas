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

    @Test func thePathAsksForBothTypesWithTheirImages() {
        let path = AssetLibraryRequests.artworkPlacementsPath(localizationID: "loc-1")
        #expect(path.hasPrefix("/v1/appStoreVersionLocalizations/loc-1/placements?"))
        #expect(path.contains("PRODUCT_PAGE_HEADER_ASSET%2CAPP_STORE_SEARCH_RESULTS_ASSET"))
        #expect(path.contains("include=image"))
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
