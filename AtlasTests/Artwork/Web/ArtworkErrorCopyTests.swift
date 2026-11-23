//
//  ArtworkErrorCopyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// WebKit's and AVFoundation's own words stay out of the message: a
/// page or loop error says what happened and what to do, and keeps the
/// system's text after "Details:".
@Suite("Artwork error copy")
struct ArtworkErrorCopyTests {
    @Test func aPageThatDidntLoadKeepsWebKitsTextForDetails() {
        let error = ArtworkWebError.loadFailed("The network connection was lost. (URLError -1005)")
        #expect(error.errorDescription == "The page didn’t load. Try again.\nDetails: The network connection was lost. (URLError -1005)")
    }

    @Test func aScriptFailureKeepsItsTextForDetails() {
        let error = ArtworkWebError.scriptFailed("A JavaScript exception occurred (WKErrorDomain 4)")
        #expect(error.errorDescription == "Atlas couldn’t fill in the page. Try again.\nDetails: A JavaScript exception occurred (WKErrorDomain 4)")
    }

    @Test func noReasonMeansNoDetails() {
        #expect(ArtworkWebError.loadFailed("").errorDescription == "The page didn’t load. Try again.")
        #expect(ArtworkLoopError.writerFailed("").errorDescription == "The loop couldn’t be written. Try again.")
    }

    @Test func aLoopWriterFailureKeepsTheSystemsTextForDetails() {
        let reason = AppleErrorCopy.details(for: NSError(domain: "AVFoundationErrorDomain", code: -11800))
        let error = ArtworkLoopError.writerFailed(reason ?? "")
        #expect(error.errorDescription?.hasPrefix("The loop couldn’t be written. Try again.\nDetails: ") == true)
        #expect(error.errorDescription?.hasSuffix("(AVFoundationErrorDomain -11800)") == true)
    }
}
