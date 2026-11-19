//
//  InAppTextsGuidelineTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Review's metadata rules in In-App Texts: an assistant's price or
/// "free" in a product's name or description is refused, an in-app
/// purchase may still be named "7-day Trial" (Guideline 3.1.1, SimProps's
/// free trial), and the person is warned in the cell and in Review & Push.
@MainActor
@Suite("In-App Texts · App Review rules")
struct InAppTextsGuidelineTests {
    private let changes = ChangeQueue()
    private let monthly = InAppTextProduct(id: "lumen.monthly", referenceName: "Monthly", kind: .subscription)
    private let trial = InAppTextProduct(id: "lumen.trial", referenceName: "Trial", kind: .inAppPurchase)

    /// A subscription whose live name says "Free", and a free-trial
    /// non-consumable.
    private var content: InAppTextsContent {
        InAppTextsContent(
            products: [monthly, trial],
            texts: [.englishUS: [
                "lumen.monthly.name": "Lumen Plus Free",
                "lumen.monthly.description": "Unlimited photos",
                "lumen.trial.name": "Trial",
                "lumen.trial.description": "Every Plus feature",
            ]],
            groupID: "grp",
            productResourceIDs: ["lumen.monthly": "sub1", "lumen.trial": "iap1"],
            productLocalizations: ["lumen.monthly": [.englishUS: "sl-en"], "lumen.trial": [.englishUS: "il-en"]],
            editableVersions: [InAppTextsContent.groupKey: "gv1", "lumen.monthly": "sv1", "lumen.trial": "iv1"]
        )
    }

    private func workspace() -> MCPWorkspace {
        let services = FakeStorePageServices()
        services.inAppTextsContent = content
        return MCPTestFixtures.workspace(apps: [StorePageContentFixtures.app], changes: changes, storePage: services)
    }

    private func propose(_ column: String, _ text: String) async throws -> MCPToolOutcome {
        let arguments: [String: JSONValue] = ["appId": "app1", "locale": "en-US", "column": .string(column), "text": .string(text)]
        return try await ProposeInAppTextsTool().call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace(), clientName: "Claude Code"))
    }

    // MARK: - propose_in_app_texts

    @Test func aPriceInASubscriptionsTextIsRefusedWithTheRule() async throws {
        let outcome = try await propose("lumen.monthly.description", "Unlimited photos for $4.99")
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["issues"] == [["kind": "pricing", "guideline": "2.3.7", "phrases": ["$4.99"]]])
        let reason = try #require(outcome.result["reason"]?.stringValue)
        #expect(reason.contains("Guideline 2.3.7"))
        #expect(reason.hasSuffix("Fix it and propose again."))
        #expect(changes.changes.isEmpty)
    }

    @Test func anInAppPurchaseMayBeNamedXXDayTrial() async throws {
        let outcome = try await propose("lumen.trial.name", "7-day Trial")
        #expect(outcome.result["status"] == "queued")
        #expect(changes.changes.first?.newValue == "7-day Trial")
        // Still no "free" in it.
        #expect(try await propose("lumen.trial.name", "7-day Free Trial").result["status"] == "refused")
    }

    @Test func aSubscriptionsTrialIsAnIntroductoryOfferNotItsName() async throws {
        let outcome = try await propose("lumen.monthly.name", "Plus · 7-day trial")
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["issues"]?.arrayValue?.first?["phrases"] == ["7-day trial"])
    }

    @Test func productNamesAreNotTheAppsName() async throws {
        // "Best" and "Early Access" only count in the app's name and subtitle.
        #expect(try await propose("lumen.monthly.name", "Best Value").result["status"] == "queued")
        #expect(try await propose("lumen.trial.description", "Early access to new themes").result["status"] == "queued")
    }

    @Test func appStoreConnectsOwnTextCanComeBack() async throws {
        #expect(try await propose("lumen.monthly.name", "Lumen Plus Free").result["status"] == "unchanged")
    }

    // MARK: - get_in_app_texts

    @Test func getCarriesTheRulesAndWhatBreaksThem() async throws {
        let outcome = try await GetInAppTextsTool().call(
            MCPToolArguments(["appId": "app1", "locales": ["en-US"]]),
            in: MCPToolContext(workspace: workspace(), clientName: "Claude Code")
        )
        #expect(outcome.result["textRules"] == StoreTextRules.inAppJSON)
        let english = try #require(outcome.result["locales"]?.arrayValue?.first)
        let state = try #require(english["states"]?["lumen.monthly.name"]?.stringValue)
        #expect(state.hasPrefix("App Review would reject it: "))
        #expect(state.contains("“Free”"))
        #expect(english["states"]?["lumen.trial.name"] == nil)
    }

    // MARK: - The person

    @Test func reviewAndPushWarnsWithTheInAppRules() throws {
        let builder = InAppTextChangeBuilder(appID: "app1", content: content)
        var matrix = content.matrix(primaryLocale: .englishUS, locales: [.englishUS])
        let trialName = try #require(matrix.columns.first { $0.id == "lumen.trial.name" })
        let monthlyName = try #require(matrix.columns.first { $0.id == "lumen.monthly.name" })
        let monthlyDescription = try #require(matrix.columns.first { $0.id == "lumen.monthly.description" })
        matrix.edit(trialName, in: .englishUS, to: "7-day Trial")
        matrix.edit(monthlyName, in: .englishUS, to: "Best Value")
        matrix.edit(monthlyDescription, in: .englishUS, to: "Only $4.99 a month")
        let pending = Dictionary(uniqueKeysWithValues: builder.changes(for: matrix).map { ($0.id, $0) })

        #expect(pending["storePage.app1.inApp.product.iap1.en-US.name"]?.guidelineIssues == [])
        #expect(pending["storePage.app1.inApp.product.sub1.en-US.name"]?.guidelineIssues == [])
        #expect(pending["storePage.app1.inApp.product.sub1.en-US.description"]?.guidelineIssues.map(\.kind) == [.pricing])
    }

    @Test func theCellWarnsAboutWhatThePersonTyped() async throws {
        let services = FakeStorePageServices()
        services.inAppTextsContent = content
        let model = InAppTextsViewModel(app: StorePageContentFixtures.app, services: services, queue: changes)
        await model.load(listing: StorePageContentFixtures.editable.listing())
        let name = try #require(model.matrix?.columns.first { $0.id == "lumen.monthly.name" })
        #expect(model.guidelineIssues(name, in: .englishUS).map(\.kind) == [.pricing])

        model.edit(name, in: .englishUS, to: "Lumen Plus")
        #expect(model.guidelineIssues(name, in: .englishUS).isEmpty)
        #expect(changes.changes.first?.newValue == "Lumen Plus")
    }

    @Test func aNewSubscriptionsTextsFollowTheRules() {
        let subscription = NewSubscription(
            group: .new(referenceName: "Plus", displayName: "Plus — Free for a week"),
            referenceName: "Plus Monthly",
            productID: "lumen.plus.monthly",
            period: .oneMonth,
            isFamilySharable: false,
            locale: .englishUS,
            displayName: "Lumen Plus",
            description: "50% off your first month",
            price: 4.99,
            reviewNote: ""
        )
        let reasons = ProposeSubscriptionTool.guidelineReasons(subscription)
        #expect(reasons.count == 2)
        #expect(reasons[0].hasPrefix("description: "))
        #expect(reasons[1].hasPrefix("groupDisplayName: "))
        #expect(NewSubscriptionField.displayName.inAppTextField == .subscriptionName)
        #expect(NewSubscriptionField.reviewNote.inAppTextField == nil)
    }

    @Test func everyPromptThatWritesInAppTextsReadsTheRules() {
        #expect(InAppTextsAskPrompt.text(app: "Lumen").contains(StoreTextRules.inAppSummary))
        #expect(NewSubscriptionAskPrompt.text(app: "Lumen").contains(StoreTextRules.inAppSummary))
        #expect(SuggestEverythingScope.inAppTextsRequest.contains(StoreTextRules.inAppSummary))
        #expect(ProposeSubscriptionTool().definition.description.contains(StoreTextRules.inAppSummary))
        let suggestAll = MCPPrompt.suggestAll.message(app: "Lumen")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(suggestAll.contains(StoreTextRules.inAppSummary))
        #expect(StoreTextRules.inAppSummary.contains("XX-day Trial"))
    }
}
