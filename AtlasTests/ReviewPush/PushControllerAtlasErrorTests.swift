//
//  PushControllerAtlasErrorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A push row shows Atlas's own errors as they are; anything else is put in
/// Atlas's words, with the system's text after "Details:".
@Suite("PushController Atlas errors")
struct PushControllerAtlasErrorTests {
    @Test func atlasOwnErrorsAreKnown() {
        #expect(PushController.isAtlasError(ProductPageAlreadyMade(name: "Widgets")))
        #expect(PushController.isAtlasError(AppStoreConnectError.unauthorized))
    }

    @Test func systemErrorsArent() {
        #expect(!PushController.isAtlasError(URLError(.badServerResponse)))
        #expect(!PushController.isAtlasError(CocoaError(.fileReadNoSuchFile)))
        #expect(!PushController.isAtlasError(NSError(domain: "WebKitErrorDomain", code: 102)))
    }

    @MainActor
    @Test func aSystemErrorIsntTheMessage() {
        let own = ProductPageAlreadyMade(name: "Widgets")
        #expect(PushController.failureText(own) == own.errorDescription)
        let system = NSError(domain: "NSCocoaErrorDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "No such file"])
        #expect(PushController.failureText(system) == "The change wasn’t sent. Try again.\nDetails: No such file (NSCocoaErrorDomain 4)")
    }
}
