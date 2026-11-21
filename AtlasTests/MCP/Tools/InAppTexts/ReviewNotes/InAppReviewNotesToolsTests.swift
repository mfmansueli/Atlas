//
//  InAppReviewNotesToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_in_app_review_notes` and `propose_in_app_review_note`: each
/// product's Review Notes for App Review, one per product, queued in Review
/// & Push as the assistant's and refused like an edit would be.
@MainActor
@Suite("In-app Review Notes")
struct InAppReviewNotesToolsTests {
    private let changes = ChangeQueue()
    private let complete = InAppTextProduct(id: "com.SimProps.complete", referenceName: "Complete", kind: .inAppPurchase)
    private let monthly = InAppTextProduct(id: "com.SimProps.monthly", referenceName: "Monthly", kind: .subscription)
    private let annual = InAppTextProduct(id: "com.SimProps.annual", referenceName: "Annual", kind: .subscription)
    private static let oldNote = "Unlocks the MCP tools set_camera and set_location."

    private var content: InAppTextsContent {
        var content = InAppTextsContent(products: [complete, monthly, annual], texts: [:], groupID: "grp")
        content.productResourceIDs = [complete.id: "iap1", monthly.id: "sub1", annual.id: "sub2"]
        content.reviewNotes = [complete.id: Self.oldNote, monthly.id: "Monthly unlocks everything."]
        content.productStates = [complete.id: "APPROVED", monthly.id: "READY_TO_SUBMIT", annual.id: "IN_REVIEW"]
        return content
    }

    private var context: MCPToolContext {
        let services = FakeStorePageServices()
        services.inAppTextsContent = content
        let workspace = MCPTestFixtures.workspace(apps: [StorePageContentFixtures.app], changes: changes, storePage: services)
        return MCPToolContext(workspace: workspace, clientName: "Claude Code")
    }

    private func propose(_ productID: String, _ note: String, reason: String? = nil) async throws -> JSONValue {
        var arguments: [String: JSONValue] = ["appId": "app1", "productId": .string(productID), "note": .string(note)]
        if let reason { arguments["reason"] = .string(reason) }
        arguments["evidence"] = [["kind": "git", "ref": "MCPTools.swift"]]
        return try await ProposeInAppReviewNoteTool().call(MCPToolArguments(arguments), in: context).result
    }

    private func read() async throws -> [JSONValue] {
        let outcome = try await GetInAppReviewNotesTool().call(MCPToolArguments(["appId": "app1"]), in: context)
        return outcome.result["products"]?.arrayValue ?? []
    }

    private func product(_ id: String, in products: [JSONValue]) -> JSONValue? {
        products.first { $0["productId"]?.stringValue == id }
    }

    // MARK: - Reading

    @Test func readsPurchasesAndSubscriptionsOncePerProduct() async throws {
        let products = try await read()
        #expect(products.count == 3)
        let iap = try #require(product(complete.id, in: products))
        #expect(iap["kind"] == "inAppPurchase")
        #expect(iap["column"] == "com.SimProps.complete.reviewNote")
        #expect(iap["note"]?.stringValue == Self.oldNote)
        #expect(iap["state"] == "APPROVED")
        #expect(iap["writesTo"] == "next review submission")
        #expect(iap["live"] == nil)
        #expect(product(monthly.id, in: products)?["kind"] == "subscription")
        #expect(product(monthly.id, in: products)?["writesTo"] == "current")
        #expect(product(annual.id, in: products)?["note"] == "")
        #expect(product(annual.id, in: products)?["writesTo"]?.stringValue?.hasPrefix("locked") == true)
    }

    @Test func aQueuedNoteIsReadWithTheLiveOne() async throws {
        _ = try await propose(complete.id, "Unlocks set_camera, set_location and record_screen.")
        let iap = try #require(try await product(complete.id, in: read()))
        #expect(iap["note"] == "Unlocks set_camera, set_location and record_screen.")
        #expect(iap["live"]?.stringValue == Self.oldNote)
        #expect(iap["queuedBy"] == "Claude Code")
    }

    // MARK: - Queuing

    @Test func aPurchasesNoteIsQueuedAsAPatchOfReviewNote() async throws {
        let note = "Start the $0 Trial (Guideline 3.1.1), then tools set_camera, set_location and record_screen unlock."
        let result = try await propose("com.SimProps.complete.reviewNote", note, reason: "1.2.0 added record_screen.")
        #expect(result["status"] == "queued")
        #expect(result["writesTo"] == "next review submission")
        let id = try #require(result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.oldValue == Self.oldNote)
        #expect(change.newValue == note)
        #expect(change.groupNote == "1.2.0 added record_screen. · git: MCPTools.swift")
        let request = try #require(change.requests.first)
        #expect(request.method == .patch)
        #expect(request.path == "/v2/inAppPurchases/iap1")
        let body = try #require(request.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let data = try #require(body["data"] as? [String: Any])
        #expect(data["type"] as? String == "inAppPurchases")
        #expect(data["id"] as? String == "iap1")
        #expect((data["attributes"] as? [String: Any])?["reviewNote"] as? String == note)
        #expect(change.restoreRequests.first?.path == "/v2/inAppPurchases/iap1")
        #expect(change.conflictCheck == ConflictCheck(path: "/v2/inAppPurchases/iap1", keyPath: ["data", "attributes", "reviewNote"], expected: Self.oldNote))
    }

    @Test func aSubscriptionsNoteIsAPatchOfTheSubscription() async throws {
        let result = try await propose(monthly.id, "Monthly unlocks every MCP tool.")
        let id = try #require(result["changeId"]?.stringValue)
        let change = try #require(changes.change(id: id))
        #expect(change.requests.first?.path == "/v1/subscriptions/sub1")
        #expect(change.requests.first?.bodyText?.contains(#""type":"subscriptions""#) == true)
    }

    @Test func proposingTheLiveNoteAgainWithdrawsTheQueuedOne() async throws {
        _ = try await propose(complete.id, "Something new.")
        #expect(changes.changes.count == 1)
        let result = try await propose(complete.id, Self.oldNote)
        #expect(result["status"] == "unchanged")
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Refusals

    @Test(arguments: [
        ("com.SimProps.complete", String(repeating: "a", count: 4001), "over_limit"),
        ("com.SimProps.complete", "   ", "empty"),
        ("com.SimProps.lifetime", "Unlocks it all.", "unknown_product"),
        ("com.SimProps.annual", "Annual unlocks it all.", "locked"),
    ])
    func refusals(productID: String, note: String, code: String) async throws {
        let result = try await propose(productID, note)
        #expect(result["status"] == "refused")
        #expect(result["code"]?.stringValue == code)
        #expect(result["reason"]?.stringValue?.isEmpty == false)
        #expect(changes.changes.isEmpty)
    }

    @Test func exactlyTheLimitIsAccepted() async throws {
        let result = try await propose(complete.id, String(repeating: "a", count: 4000))
        #expect(result["status"] == "queued")
    }

    @Test func notesThePersonChangedAreTheirs() async throws {
        let builder = InAppReviewNoteChangeBuilder(appID: "app1", content: content)
        let mine = try #require(builder.change(complete, to: "My own notes.", source: .you))
        changes.upsert(mine)
        let result = try await propose(complete.id, "The assistant's notes.")
        #expect(result["status"] == "refused")
        #expect(result["code"] == "changed_by_person")
        #expect(changes.change(id: mine.id)?.newValue == "My own notes.")
    }

    @Test func aBatchReportsEach() async throws {
        let arguments: [String: JSONValue] = [
            "appId": "app1",
            "notes": [
                ["productId": .string(complete.id), "note": "New notes."],
                ["productId": .string(annual.id), "note": "Locked."],
            ],
        ]
        let result = try await ProposeInAppReviewNoteTool().call(MCPToolArguments(arguments), in: context).result
        #expect(result["queued"] == 1)
        #expect(result["refused"] == 1)
    }
}
