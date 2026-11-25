//
//  WatchPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The prompt a run starts with names only Atlas's real tools, keeps the
/// expensive ones away, and says nothing for local-only findings.
@Suite("Look for Improvements · prompt")
struct WatchPromptTests {
    private typealias Data = WatchTestData
    private let sent: [WatchSignal] = [
        Data.signal(.eventDeadline, subject: "6740000001"),
        Data.signal(.whatsNewMissing),
        Data.signal(.crashesWorse, subject: "1.4"),
        Data.signal(.reviewsAfterRelease, subject: "1.4"),
    ]

    @Test(arguments: WatchSignalKind.allCases)
    func everyKindsToolsAreAtlasTools(_ kind: WatchSignalKind) {
        let tools = WatchPrompt.tools(for: kind)
        #expect(Set(tools.all).isSubset(of: MCPToolbox.standard.toolNames))
        #expect(kind.isLocalOnly == tools.all.isEmpty)
        #expect(Set(tools.all).isDisjoint(with: WatchPrompt.neverCalled))
    }

    @Test func theToolsNeverCalledExist() {
        #expect(Set(WatchPrompt.neverCalled).isSubset(of: MCPToolbox.standard.toolNames))
    }

    @Test func thePromptNamesOnlyAtlassTools() throws {
        let text = try #require(WatchPrompt.text(appID: Data.lumen, appName: "Lumen Journal", signals: sent))
        let regex = try Regex(#"\b(?:get|propose|suggest|add|report|render|request|start|revise|next|list|mark|begin|end|answer|update)_[a-z_]+"#)
        let named = Set(text.matches(of: regex).map { String(text[$0.range]) })
        #expect(!named.isEmpty)
        #expect(named.isSubset(of: MCPToolbox.standard.toolNames), "unknown: \(named.subtracting(MCPToolbox.standard.toolNames).sorted())")
        #expect(named.isSubset(of: WatchPrompt.toolNames(for: sent)))
        for kind in [WatchSignalKind.eventDeadline, .whatsNewMissing, .crashesWorse, .reviewsAfterRelease] {
            for tool in WatchPrompt.tools(for: kind).all {
                #expect(text.contains(tool))
            }
        }
    }

    @Test func thePromptListsEachFindingWithItsSubject() throws {
        let text = try #require(WatchPrompt.text(appID: Data.lumen, appName: "Lumen Journal", signals: sent))
        #expect(text.contains("Lumen Journal"))
        #expect(text.contains("appId 6450000001"))
        #expect(text.contains("1. eventDeadline 6740000001"))
        #expect(text.contains("eventId \"6740000001\""))
        #expect(text.contains("4. reviewsAfterRelease 1.4"))
        #expect(text.contains("You can't push"))
    }

    @Test func thePromptKeepsAtlassVoice() throws {
        let text = try #require(WatchPrompt.text(appID: Data.lumen, appName: "Lumen Journal", signals: sent)).lowercased()
        for word in ["simply", "just", "easily", "seamlessly", "powerful", "leverage", "ai-powered", "magic", "please", "oops", "successfully", "!"] {
            #expect(!text.contains(word), "\(word)")
        }
    }

    @Test func localOnlyFindingsAreLeftOut() throws {
        let blocked = Data.signal(.submissionBlocked, subject: "v15")
        #expect(WatchPrompt.text(appID: Data.lumen, appName: "Lumen", signals: [blocked]) == nil)
        #expect(WatchPrompt.text(appID: Data.lumen, appName: "Lumen", signals: []) == nil)
        let text = try #require(WatchPrompt.text(appID: Data.lumen, appName: "Lumen", signals: [blocked, Data.signal()]))
        #expect(!text.contains("submissionBlocked"))
        #expect(text.contains("1. whatsNewMissing"))
    }
}
