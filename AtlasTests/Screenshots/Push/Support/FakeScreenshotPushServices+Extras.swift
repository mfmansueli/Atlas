//
//  FakeScreenshotPushServices+Extras.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

extension FakeScreenshotPushServices: ExtrasPushProviding {
    var assetLibrary: any AssetLibraryPushing { extrasLibrary }
    var productPageTesting: any ProductPageTesting { productPageTester }
    var assetLibraryFiles: any AssetLibraryManaging { FakeAssetLibraryFiles([]) }
}
#endif
