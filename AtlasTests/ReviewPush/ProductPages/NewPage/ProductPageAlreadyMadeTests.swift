//
//  ProductPageAlreadyMadeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new page whose name App Store Connect already has (an earlier push
/// made it although Apple answered with an error) isn't made again: it
/// fails saying so, and the rest of the push goes on.
@MainActor
@Suite("A page an earlier push made")
struct ProductPageAlreadyMadeTests {
    private let queue = ChangeQueue()
    private static let pages = ProductPageScreenshotsPush.pagesPath(appID: "alba")

    private func create(_ name: String) -> PendingChange {
        let body = #"{"data":{"type":"appCustomProductPages","attributes":{"name":"\#(name)"}}}"#
        return PendingChange(
            id: "productPages.alba.\(name).new", appID: "alba", section: .productPages, group: "Custom Product Pages", title: "Create “\(name)”",
            oldValue: "", newValue: name,
            requests: [PushRequest(method: .post, path: "/v1/appCustomProductPages", body: Data(body.utf8))]
        )
    }

    private func push(_ changes: [PendingChange], remote: [String: Data]) async -> (PushController, FakePushTransport) {
        let made = Data(#"{"data":{"type":"appCustomProductPages","id":"p-2"}}"#.utf8)
        let transport = FakePushTransport(remote: remote, responses: ["/v1/appCustomProductPages": made])
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        controller.productPagePacing = .immediate
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return (controller, transport)
    }

    @Test func itIsntMadeAgain() async {
        let list = Data(#"{"data":[{"type":"appCustomProductPages","id":"p-1","attributes":{"name":"Widgets & Lock Screen"}}]}"#.utf8)
        let (controller, transport) = await push([create("Widgets & Lock Screen"), create("Gratitude")], remote: [Self.pages: list])
        let widgets = controller.items.first { $0.change.newValue == "Widgets & Lock Screen" }
        #expect(widgets?.status == .failed(ProductPageAlreadyMade(name: "Widgets & Lock Screen").errorDescription ?? ""))
        #expect(transport.sent.count == 1)
        #expect(ProductPageAlreadyMade.name(creating: transport.sent[0]) == "Gratitude")
        #expect(queue.changes.map(\.newValue) == ["Widgets & Lock Screen"])
        #expect(controller.items.first { $0.change.newValue == "Gratitude" }?.createdIDs["appCustomProductPages"] == "p-2")
    }

    @Test func otherRequestsArentChecked() {
        #expect(ProductPageAlreadyMade.name(creating: PushRequest(method: .patch, path: "/v1/appCustomProductPages/p-1", body: nil)) == nil)
    }
}
