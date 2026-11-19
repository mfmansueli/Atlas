//
//  StorePageGuidelineTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Review's metadata rules in the Store Page: the field warns about
/// what the person typed (they can still push it), Generate Suggestions…
/// drops what breaks a rule, and Review & Push warns on the change.
@MainActor
@Suite("Store Page guideline warnings")
struct StorePageGuidelineTests {
    private let app = StorePageContentFixtures.app
    private let queue = ChangeQueue()
    private let suggestions = FieldSuggestionStore()

    private func makeModel() async -> StorePageViewModel {
        let model = StorePageViewModel(app: app, services: FakeStorePageServices(), queue: queue, suggestions: suggestions)
        await model.load()
        return model
    }

    @Test func aFieldWarnsAboutWhatThePersonTypedAndStillQueuesIt() async {
        let model = await makeModel()
        #expect(model.guidelineIssues(.subtitle, in: .englishUS).isEmpty)

        model.edit(.subtitle, in: .englishUS, to: "Free notes, no ads")
        #expect(model.guidelineIssues(.subtitle, in: .englishUS) == [StoreTextGuidelineIssue(kind: .pricing, phrases: ["Free"])])
        #expect(queue.changes.contains { $0.newValue == "Free notes, no ads" })
    }

    @Test func generatedSuggestionsThatBreakARuleAreDropped() async {
        let model = await makeModel()
        let added = model.addGeneratedSuggestions([
            KeyAssistantSuggestionItem(locale: "en-US", field: "promotionalText", value: "Try Lumen free for 7 days.", reason: nil),
            KeyAssistantSuggestionItem(locale: "en-US", field: "subtitle", value: "The #1 journal", reason: nil),
            KeyAssistantSuggestionItem(locale: "en-US", field: "promotionalText", value: "Weekly reflections are here.", reason: nil),
        ], client: "Claude")
        #expect(added == 1)
        #expect(suggestions.suggestions.filter { $0.source == .assistant(client: "Claude") }.map(\.value) == ["Weekly reflections are here."])
    }

    @Test func reviewAndPushWarnsOnStorePageTextOnly() {
        let subtitle = PendingChange(
            id: "storePage.app1.appInfo.info.en-US.subtitle", appID: "app1", section: .storePage, group: "g", title: "t",
            oldValue: "", newValue: "Now on Android", requests: []
        )
        #expect(subtitle.guidelineIssues.map(\.kind) == [.otherPlatform])

        let url = PendingChange(
            id: "storePage.app1.version.v2.en-US.supportUrl", appID: "app1", section: .storePage, group: "g", title: "t",
            oldValue: "", newValue: "https://free.example", requests: []
        )
        #expect(url.guidelineIssues.isEmpty)

        let price = PendingChange(
            id: "pricing.app1.BRA", appID: "app1", section: .subscriptionPricing, group: "g", title: "t", oldValue: "", newValue: "Free", requests: []
        )
        #expect(price.guidelineIssues.isEmpty)
    }

    @Test func everyAssistantReadsTheRulesBeforeWriting() {
        #expect(MCPEndpoint.instructions.contains(StoreTextRules.summary))
        #expect(KeyAssistantStorePrompt.system.contains(StoreTextRules.summary))
        for prompt in [MCPPrompt.translateMissing, .suggestAll, .shortenOverflowingCaptions, .translateCaptions] {
            let text = prompt.message(app: "Lumen")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
            #expect(text.contains(StoreTextRules.summary), "\(prompt)")
        }
        let suggest = MCPPrompt.suggest.message(app: "Lumen", area: "store")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(suggest.contains(StoreTextRules.summary))
        let whatsNew = MCPPrompt.whatsNewFromGit.message(app: "Lumen")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(whatsNew.contains("2.3.12"))
        let screenshots = MCPPrompt.runScreenshots.message(app: "Lumen")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(screenshots.contains("2.3.9") && screenshots.contains("2.3.7"))
    }
}
