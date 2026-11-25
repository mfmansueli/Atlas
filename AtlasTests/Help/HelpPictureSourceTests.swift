//
//  HelpPictureSourceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Help's pictures of App Store Connect are drawn, not bundled
/// (README-Welcome's "Connect to App Store Connect").
@Suite("Help pictures")
struct HelpPictureSourceTests {
    @Test func theConnectPicturesAreDrawings() {
        #expect(HelpPictureSource(name: "help-connect-1") == .drawing(.connectIntegrations))
        #expect(HelpPictureSource(name: "help-connect-2") == .drawing(.connectTeamKey))
        #expect(HelpPictureSource(name: "help-connect-3") == .drawing(.connectDownload))
        #expect(HelpPictureSource(name: "help-connect-4") == .drawing(.connectIDs))
        #expect(HelpDrawing.allCases.map(\.rawValue) == ["help-connect-1", "help-connect-2", "help-connect-3", "help-connect-4"])
    }

    /// Any other name is a bundled image, so a screenshot can still be
    /// added under its own name.
    @Test func anyOtherNameIsAnImage() {
        #expect(HelpPictureSource(name: "help-assistant-1") == .asset("help-assistant-1"))
        #expect(HelpPictureSource(name: "help-connect-5") == .asset("help-connect-5"))
        #expect(HelpPictureSource(name: "Help-Connect-1") == .asset("Help-Connect-1"))
    }

    @Test func theParserStillMakesPictureBlocks() {
        #expect(HelpArticleParser.blocks([
            "3. **Download the key file.**",
            "",
            "![Download in your key’s row](help-connect-3)",
        ]) == [
            .steps(["**Download the key file.**"], start: 3),
            .image(name: "help-connect-3", caption: "Download in your key’s row"),
        ])
    }

    @Test func theArticleDrawsItsFourPicturesInOrder() throws {
        let library = HelpLibrary(bundle: Bundle(for: AppPreferences.self))
        let article = try #require(library.article(ConnectBeforeYouStart.helpArticleID))
        let names = article.blocks.compactMap { block -> String? in
            if case let .image(name, _) = block { return name }
            return nil
        }
        #expect(names == ["help-connect-1", "help-connect-2", "help-connect-3", "help-connect-4"])
        #expect(names.map(HelpPictureSource.init(name:)) == HelpDrawing.allCases.map(HelpPictureSource.drawing))
    }

    /// VoiceOver reads one label per picture, naming what to click.
    @Test func everyDrawingHasItsOwnLabel() {
        let labels = HelpDrawing.allCases.map(\.accessibilityLabel)
        #expect(Set(labels).count == HelpDrawing.allCases.count)
        #expect(labels.allSatisfy { $0.hasPrefix("Picture: in App Store Connect, ") })
        #expect(HelpDrawing.connectIntegrations.accessibilityLabel == "Picture: in App Store Connect, Users and Access, then Integrations")
    }
}
