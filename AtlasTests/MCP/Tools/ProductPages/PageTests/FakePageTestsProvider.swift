//
//  FakePageTestsProvider.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Review & Push's extras services for the page test tools: App Store
/// Connect's tests, reference data and library, all fakes.
struct FakePageTestsProvider: ExtrasPushProviding {
    let tester: FakeProductPageTesting
    let library: FakeAssetLibrary
    let files: FakeAssetLibraryFiles

    var assetLibrary: any AssetLibraryPushing { library }
    var productPageTesting: any ProductPageTesting { tester }
    var assetLibraryFiles: any AssetLibraryManaging { files }

    init(_ script: FakeProductPageTesting.Script = .init(), files: [AssetLibraryFile] = []) {
        tester = FakeProductPageTesting(script)
        library = FakeAssetLibrary()
        self.files = FakeAssetLibraryFiles(files: files)
    }
}
