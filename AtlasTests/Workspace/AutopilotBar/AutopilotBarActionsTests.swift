//
//  AutopilotBarActionsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The section's actions in the Autopilot bar (board 80): its first two
/// beside the closed field, the rest under More with Everything for the
/// app last; narrow, the buttons fold into More one at a time.
@Suite("Autopilot bar · actions")
struct AutopilotBarActionsTests {
    private func actions(_ section: AppWorkspaceSection) -> AutopilotBarActions {
        AutopilotBarActions(
            items: WorkspaceAutopilotAction.actions(for: section).map { WorkspaceAutopilotItem(action: $0, title: $0.title()) },
            everythingTitle: AutopilotBarActions.everythingTitle(section: section, appName: "Lumen")
        )
    }

    @Test(arguments: AppWorkspaceSection.allCases)
    func theFirstTwoActionsAreButtons(_ section: AppWorkspaceSection) {
        let bar = actions(section)
        let all = WorkspaceAutopilotAction.actions(for: section)
        #expect(bar.buttons().map(\.action) == Array(all.prefix(2)))
        #expect(bar.buttons().count <= AutopilotBarActions.buttonLimit)
        #expect(bar.primary?.action == all.first)
    }

    @Test(arguments: AppWorkspaceSection.allCases)
    func moreHasTheRestAndNothingTwice(_ section: AppWorkspaceSection) {
        let bar = actions(section)
        let all = WorkspaceAutopilotAction.actions(for: section)
        #expect(bar.more().map(\.action) == Array(all.dropFirst(2)))
        #expect(Set(bar.buttons().map(\.action)).isDisjoint(with: bar.more().map(\.action)))
        #expect(bar.buttons().count + bar.more().count == all.count)
    }

    @Test func theStorePagesButtonsAreSuggestTextsAndTranslate() {
        let bar = actions(.storePage)
        #expect(bar.buttons().map(\.action) == [.suggestTexts, .translateNewLanguage])
        #expect(bar.buttons().map { $0.action.shortTitle(fullTitle: $0.title) } == ["Suggest Texts", "Translate"])
        #expect(bar.more().map(\.action) == [.suggestSourceLanguageOnly])
    }

    @Test func narrowTheButtonsFoldIntoMore() {
        let bar = actions(.screenshots)
        #expect(bar.buttons(fitting: 1).count == 1)
        #expect(bar.more(fitting: 1).first == bar.items[1])
        #expect(bar.buttons(fitting: 0).isEmpty)
        #expect(bar.more(fitting: 0) == bar.items)
        // Never more than two, never fewer than none.
        #expect(bar.buttons(fitting: 5).count == 2)
        #expect(bar.buttons(fitting: -1).isEmpty)
        #expect(AutopilotBarActions.fittingOrder == [2, 1, 0])
    }

    @Test func everythingIsLastInMoreButNotOnOverview() {
        #expect(actions(.storePage).everythingTitle == "Everything for Lumen…")
        #expect(actions(.overview).everythingTitle == nil)
        #expect(actions(.overview).primary?.action == .suggestEverything)
    }

    @Test func noButtonEndsWithAnEllipsis() {
        let all = Set(AppWorkspaceSection.allCases.flatMap(WorkspaceAutopilotAction.actions(for:)))
        for action in all {
            let short = action.shortTitle(fullTitle: action.title())
            #expect(!short.hasSuffix("…"), "\(action)")
            #expect(!short.isEmpty, "\(action)")
            #expect(action.subtitle?.isEmpty == false, "\(action)")
        }
    }

    @Test func noSectionOffersAskSomethingElse() {
        // The bar's field asks; there's no “Ask Something Else…” any more.
        for section in AppWorkspaceSection.allCases {
            #expect(!WorkspaceAutopilotAction.actions(for: section).map { $0.title() }.contains { $0.hasPrefix("Ask") }, "\(section)")
        }
    }
}
