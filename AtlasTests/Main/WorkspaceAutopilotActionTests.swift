//
//  WorkspaceAutopilotActionTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The toolbar Autopilot button's actions, section by section (board 57).
@Suite("WorkspaceAutopilotAction")
struct WorkspaceAutopilotActionTests {
    @Test func eachSectionLeadsWithWhatAutopilotMakesThere() {
        let leads = AppWorkspaceSection.allCases.map { WorkspaceAutopilotAction.actions(for: $0).first?.title() }
        #expect(leads == AppWorkspaceSection.allCases.map(Self.lead))
    }

    private static func lead(_ section: AppWorkspaceSection) -> String {
        switch section {
        case .overview: "Suggest Everything…"
        case .storePage: "Suggest Texts…"
        case .screenshots: "Make Screenshots…"
        case .productPages: "Suggest Pages…"
        case .inAppEvents: "Make Event Artwork…"
        case .nominations: "Suggest a Nomination…"
        case .appInformation: "Suggest Answers…"
        case .subscriptionPricing: "Suggest Prices…"
        case .reviews: "Draft Replies…"
        case .analytics: "Find What to Try…"
        }
    }

    @Test func noActionIsListedTwiceInASection() {
        for section in AppWorkspaceSection.allCases {
            let actions = WorkspaceAutopilotAction.actions(for: section)
            #expect(Set(actions).count == actions.count, "\(section)")
        }
    }

    @Test func titlesNameTheVersionAndTheLanguage() {
        #expect(WorkspaceAutopilotAction.writeWhatsNew.title(version: "1.4") == "Write What’s New for 1.4…")
        #expect(WorkspaceAutopilotAction.writeWhatsNew.title() == "Write What’s New…")
        #expect(WorkspaceAutopilotAction.suggestSourceLanguageOnly.title(sourceLanguage: "English (U.S.)") == "Suggest for English (U.S.) Only…")
    }

    /// Board 58: Reviews offers Reply Automatically…, which opens its
    /// settings there; Free sees them too, with Upgrade….
    @Test func reviewsCanReplyAutomatically() {
        #expect(WorkspaceAutopilotAction.actions(for: .reviews).contains(.replyAutomatically))
        #expect(WorkspaceAutopilotAction.replyAutomatically.title() == "Reply Automatically…")
        #expect(WorkspaceAutopilotAction.replyAutomatically.section == .reviews)
        #expect(WorkspaceAutopilotAction.replyAutomatically.paywall == nil)
    }

    @Test func whatMakesThingsIsPro() {
        #expect(WorkspaceAutopilotAction.makeScreenshots.paywall == .autopilot)
        #expect(WorkspaceAutopilotAction.makePageScreenshots.paywall == .autopilot)
        #expect(WorkspaceAutopilotAction.makeEventArtwork.paywall == .eventArtwork)
        #expect(WorkspaceAutopilotAction.writeRetentionOffer.paywall == .retention)
        #expect(WorkspaceAutopilotAction.suggestTexts.paywall == nil)
        #expect(WorkspaceAutopilotAction.suggestEverything.paywall == nil)
    }

    /// A section's flow runs there; every other action is a request the
    /// toolbar sends Claude Code, with a prompt.
    @Test func everyActionEitherRunsASectionsFlowOrAsks() {
        let all = Set(AppWorkspaceSection.allCases.flatMap(WorkspaceAutopilotAction.actions(for:)))
        for action in all {
            let ask = WorkspaceAutopilotAsk.make(action, app: "Lumen", version: "1.4", sourceLanguage: "English", question: "Why?")
            if action.section != nil {
                #expect(ask == nil, "\(action)")
                #expect(!action.asksAssistant)
            } else {
                #expect(ask?.prompt.contains("Lumen") == true, "\(action)")
                #expect(action.asksAssistant)
            }
        }
    }

    /// Inside an event or a product page the button leads with what it
    /// makes for that page; the menu keeps the section's other actions.
    @Test func aDetailPageLeadsWithItsOwnAction() {
        let event = WorkspaceAutopilotAction.actions(for: .inAppEvents, detail: .event)
        #expect(event.first == .makeEventArtwork)
        #expect(Set(event) == Set(WorkspaceAutopilotAction.actions(for: .inAppEvents)))
        #expect(WorkspaceAutopilotAction.makeEventArtwork.title(detail: .event) == "Make the Artwork…")
        #expect(WorkspaceAutopilotAction.makeEventArtwork.title() == "Make Event Artwork…")

        let page = WorkspaceAutopilotAction.actions(for: .productPages, detail: .productPage)
        #expect(page == [.makePageScreenshots, .suggestPages])
        #expect(WorkspaceAutopilotAction.makePageScreenshots.title(detail: .productPage) == "Make Screenshots for This Page…")
        #expect(WorkspaceAutopilotAction.suggestPages.title(detail: .productPage) == "Suggest Pages…")
    }

    /// Board 74 · 3: an empty In-App Events leads with Suggest an Event…,
    /// which asks the assistant, not with Make Event Artwork….
    @Test func noEventsLeadsWithSuggestAnEvent() {
        let empty = WorkspaceAutopilotAction.actions(for: .inAppEvents, detail: .noEvents)
        #expect(empty.first == .suggestEvent)
        #expect(Set(empty) == Set(WorkspaceAutopilotAction.actions(for: .inAppEvents)))
        #expect(WorkspaceAutopilotAction.suggestEvent.title() == "Suggest an Event…")
        #expect(WorkspaceAutopilotAction.suggestEvent.asksAssistant)
        #expect(WorkspaceAutopilotAction.suggestEvent.paywall == nil)
        #expect(WorkspaceAutopilotAsk.make(.suggestEvent, app: "Lumen")?.prompt.contains("propose_in_app_event") == true)
        #expect(WorkspaceAutopilotAction.actions(for: .nominations, detail: .noEvents) == WorkspaceAutopilotAction.actions(for: .nominations))
    }

    @Test func aDetailOfAnotherSectionChangesNothing() {
        #expect(WorkspaceAutopilotAction.actions(for: .screenshots, detail: .event) == WorkspaceAutopilotAction.actions(for: .screenshots))
        #expect(WorkspaceAutopilotAction.actions(for: .productPages, detail: nil).first == .suggestPages)
    }

    @Test func theSectionFlowsOpenWhereTheyLive() {
        #expect(WorkspaceAutopilotAction.makeAppPreview.section == .screenshots)
        #expect(WorkspaceAutopilotAction.makePageScreenshots.section == .productPages)
        #expect(WorkspaceAutopilotAction.makeEventArtwork.section == .inAppEvents)
        #expect(WorkspaceAutopilotAction.checkPrivacy.section == .appInformation)
    }
}
