//
//  AssistantChatPartsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Chat · steps, suggestions, starters and the run")
@MainActor
struct AssistantChatPartsTests {
    @Test func stepsComeFromToolsFilesAndCommands() {
        let date = Date()
        let activity = [
            ClaudeCodeActivity(id: 1, date: date, kind: .started, text: "Claude Code started"),
            ClaudeCodeActivity(id: 2, date: date, kind: .atlas, text: "get_store_page"),
            ClaudeCodeActivity(id: 3, date: date, kind: .atlas, text: "get_store_page"),
            ClaudeCodeActivity(id: 4, date: date, kind: .file, text: "Read CHANGELOG.md"),
            ClaudeCodeActivity(id: 5, date: date, kind: .command, text: "git log v1.3..HEAD --oneline"),
            ClaudeCodeActivity(id: 6, date: date, kind: .said, text: "Looking at prices"),
            ClaudeCodeActivity(id: 7, date: date, kind: .atlas, text: "propose_prices"),
            ClaudeCodeActivity(id: 8, date: date, kind: .atlas, text: "ask_in_chat"),
            ClaudeCodeActivity(id: 9, date: date, kind: .atlas, text: "render_preview"),
        ]
        #expect(AssistantChatStep.steps(from: activity).map(\.text) == [
            "Read store page", "Read CHANGELOG.md", "Run git log", "Suggest prices", "Ask you", "Render preview",
        ])
    }

    @Test func suggestionsAreGroupedByTheirSection() throws {
        let start = Date(timeIntervalSince1970: 0)
        func entry(_ second: Double, _ tool: String, _ target: String, _ outcome: MCPCallOutcome = .proposed) -> MCPLogEntry {
            MCPLogEntry(date: start.addingTimeInterval(second), client: "Claude Code", tool: tool, target: target, outcome: outcome)
        }
        let log = [
            entry(1, "suggest_fields", "Lumen · de-DE · Subtitle"),
            entry(2, "propose_listing_text", "Lumen · ja · Keywords"),
            entry(3, "propose_prices", "Lumen · Annual · Brazil"),
            entry(4, "propose_prices", "Lumen · Annual", .refused),
            entry(5, "propose_prices", "Tempo · Annual"),
        ]
        let suggestions = try #require(AssistantChatSuggestions.make(from: log, appName: "Lumen", start: start, end: start.addingTimeInterval(10)))
        #expect(suggestions.count == 3)
        #expect(suggestions.section == .storePage)
        #expect(suggestions.title == "3 suggestions in Store Page")
        #expect(suggestions.why == "de-DE · Subtitle, ja · Keywords and 1 more")
        #expect(AssistantChatSuggestions.make(from: [], appName: "Lumen", start: start, end: start) == nil)
        #expect(AssistantChatSuggestions(targets: ["x"], section: nil).title == "1 suggestion")
    }

    @Test func aNewVersionAndItsTextsPointToReviewAndPush() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let end = start.addingTimeInterval(30)
        let log = [
            MCPLogEntry(
                date: start.addingTimeInterval(5), client: "Claude Code", tool: "propose_app_version",
                target: "Lumen · Version 1.5 · iOS", outcome: .proposed
            ),
            MCPLogEntry(
                date: start.addingTimeInterval(8), client: "Claude Code", tool: "suggest_fields", target: "Lumen · en-US · What's New", outcome: .proposed
            ),
        ]
        let claude = ChangeSource.assistant(client: "Claude Code")
        let version = NewAppVersionChangeBuilder(appID: "1").change(
            for: NewAppVersion(versionString: "1.5", platform: "IOS"), showsPlatform: false, source: claude, at: start.addingTimeInterval(5)
        )
        let suggestions = try #require(AssistantChatSuggestions.make(from: log, appName: "Lumen", start: start, end: end, queued: [version]))
        #expect(suggestions.waitsInReview)
        #expect(suggestions.title == "2 suggestions in Review & Push")
        #expect(suggestions.why == "Version 1.5 · iOS, en-US · What's New")

        // The person's own version, or one queued before this answer, isn't the answer's.
        var yours = version
        yours.source = .you
        var earlier = version
        earlier.createdAt = start.addingTimeInterval(-60)
        for change in [yours, earlier] {
            let other = try #require(AssistantChatSuggestions.make(from: log, appName: "Lumen", start: start, end: end, queued: [change]))
            #expect(!other.waitsInReview)
            #expect(other.title == "2 suggestions in Store Page")
        }

        // A text tied to a version queued before still waits with it.
        var tied = version
        tied.id = "listing.{queuedVersion:IOS:1.5}.en-US.whatsNew"
        tied.dependsOn = version.id
        let text = try #require(AssistantChatSuggestions.make(from: Array(log.suffix(1)), appName: "Lumen", start: start, end: end, queued: [earlier, tied]))
        #expect(text.waitsInReview)
        #expect(text.title == "1 suggestion in Review & Push")
    }

    @Test func showingASectionOpensItsSuggestions() {
        #expect(AssistantChatSuggestions.intent(showing: .subscriptionPricing) == .reviewSuggestions)
        #expect(AssistantChatSuggestions.intent(showing: .storePage) == .reviewFieldSuggestions(.storePage))
        #expect(AssistantChatSuggestions.intent(showing: .appInformation) == .reviewFieldSuggestions(.appInformation))
        #expect(AssistantChatSuggestions.intent(showing: .analytics) == nil)
    }

    @Test func theChatAnswersInThePersonsLanguage() {
        #expect(ClaudeCodePermissions.chat.systemPrompt.contains("Write it in the language the person writes in"))
    }

    @Test func toolsMapToTheirSections() {
        #expect(AssistantChatSuggestions.section(forTool: "propose_review_replies") == .reviews)
        #expect(AssistantChatSuggestions.section(forTool: "propose_event_texts") == .inAppEvents)
        #expect(AssistantChatSuggestions.section(forTool: "propose_page_screenshots") == .productPages)
        #expect(AssistantChatSuggestions.section(forTool: "propose_captions") == .screenshots)
        #expect(AssistantChatSuggestions.section(forTool: "propose_age_rating") == .appInformation)
        #expect(AssistantChatSuggestions.section(forTool: "add_finding") == .analytics)
        #expect(AssistantChatSuggestions.section(forTool: "propose_app_version") == .storePage)
        #expect(AssistantChatSuggestions.section(forTool: "propose_win_back_offer") == .subscriptionPricing)
        #expect(AssistantChatSuggestions.section(forTool: "get_listing") == nil)
    }

    @Test func everySectionOffersThreeOrTwoStarters() {
        for section in AppWorkspaceSection.allCases {
            let starters = AssistantChatStarters.starters(for: section)
            #expect(starters.last == "What changed since last month?")
            #expect(starters.count == (section == .overview ? 2 : 3))
        }
        #expect(AssistantChatStarters.starters(for: .subscriptionPricing).first == "Which countries lose the most sales?")
    }

    @Test func aRemovedVersionChipLeavesThePrompt() {
        let context = AssistantChatContext(appID: "1", appName: "Lumen", section: .reviews, version: "1.4")
        let prompt = AssistantChatPrompt.prompt("Why?", context: context, removed: [AssistantChatContext.versionChip], isFollowUp: false, answers: nil)
        #expect(prompt.contains("Reviews section of Lumen (app ID 1)"))
        #expect(!prompt.contains("1.4"))
        #expect(prompt.contains("They ask in Atlas's chat: Why?"))
    }

    @Test func pricingsCountryIsAChipThatReachesThePrompt() {
        let context = AssistantChatContext(appID: "1", appName: "Lumen", section: .subscriptionPricing, version: "1.4", country: "Brazil")
        let chips = context.chips(removing: [])
        #expect(chips.map(\.label) == ["Lumen", "Pricing", "Version 1.4", "Brazil"])
        #expect(chips.last?.isRemovable == true)
        #expect(chips.last?.id == AssistantChatContext.countryChip)
        let prompt = AssistantChatPrompt.prompt("Too expensive?", context: context, removed: [], isFollowUp: false, answers: nil)
        #expect(prompt.contains("with Brazil chosen as the country its prices show"))
        let removed: Set<String> = [AssistantChatContext.countryChip]
        #expect(context.chips(removing: removed).map(\.id) == ["app", "section", AssistantChatContext.versionChip])
        #expect(!AssistantChatPrompt.prompt("Too expensive?", context: context, removed: removed, isFollowUp: false, answers: nil).contains("Brazil"))
    }

    @Test func aFollowUpResumesClaudeCodesSession() {
        var invocation = ClaudeCodeInvocation(
            workingDirectory: "/tmp", prompt: "Hi", permissions: .chat, port: 47321, token: "t", sessionName: "Atlas · Chat · Lumen"
        )
        #expect(!invocation.claudeArguments.contains("--resume"))
        invocation.resumeSessionID = "abc"
        #expect(Array(invocation.claudeArguments.prefix(4)) == ["--resume", "abc", "-p", "Hi"])
    }

    @Test func chatRunsReadAndMayAskThePerson() {
        let chat = ClaudeCodePermissions.chat
        #expect(ClaudeCodeRunPurpose.chat.permissions == chat)
        #expect(chat.tools == ClaudeCodePermissions.readProject.tools)
        #expect(chat.allowRules(port: 1) == ClaudeCodePermissions.readProject.allowRules(port: 1))
        #expect(chat.systemPrompt.contains("ask_in_chat"))
        #expect(!chat.systemPrompt.contains("don't ask questions"))
        #expect(ClaudeCodePermissions.readProject.systemPrompt.contains("don't ask questions"))
    }

    @Test func outsideClicksAreMeasuredFromTheTop() {
        let frame = CGRect(x: 600, y: 200, width: 420, height: 500)
        // AppKit's y counts from the bottom of an 800-pt window.
        #expect(!AssistantChatOutsideClick.isOutside(CGPoint(x: 700, y: 300), frame: frame, windowHeight: 800))
        #expect(AssistantChatOutsideClick.isOutside(CGPoint(x: 100, y: 300), frame: frame, windowHeight: 800))
        #expect(AssistantChatOutsideClick.isOutside(CGPoint(x: 700, y: 750), frame: frame, windowHeight: 800))
        #expect(!AssistantChatOutsideClick.isOutside(CGPoint(x: 100, y: 300), frame: .zero, windowHeight: 800))
    }

    @Test func askInChatRefusesWhatTheChatCantShow() {
        let choices = ["Only Subscriptions", "Every Product"]
        #expect(AskInChatTool.refusal(question: "Count every product, or only subscriptions?", choices: choices) == nil)
        #expect(AskInChatTool.refusal(question: "", choices: choices) != nil)
        #expect(AskInChatTool.refusal(question: "One two three four five six seven eight nine?", choices: choices) != nil)
        #expect(AskInChatTool.refusal(question: "Which?", choices: ["Only"]) == "choices has 1; give 2 to 4.")
        #expect(AskInChatTool.refusal(question: "Which?", choices: ["A", "a"]) == "Two choices are the same.")
        #expect(AskInChatTool.refusal(question: "Which?", choices: ["A", String(repeating: "x", count: 29)]) != nil)
    }
}
