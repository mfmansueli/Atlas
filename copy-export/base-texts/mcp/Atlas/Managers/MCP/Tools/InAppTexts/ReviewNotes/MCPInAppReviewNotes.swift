//
//  MCPInAppReviewNotes.swift
//  Atlas
//

import Foundation

/// One app's Review Notes for App Review, one per subscription and in-app
/// purchase, as an assistant sees them: App Store Connect's with anything
/// queued on top, each product's state and where an edit goes. Proposals
/// are checked like an edit and queued in Review & Push as the assistant's.
@MainActor
struct MCPInAppReviewNotes {
    let app: StoreApp
    let content: InAppTextsContent
    let builder: InAppReviewNoteChangeBuilder
    /// Queued notes changes, by product ID.
    let queued: [String: PendingChange]

    /// How one proposal went.
    enum Outcome: Equatable {
        case queued(PendingChange)
        /// Already the notes (queued or in App Store Connect).
        case unchanged
        /// App Store Connect's notes again: the queued change is withdrawn.
        case backToLive(PendingChange.ID)
        case refused(code: String, reason: String)
    }

    static func load(app identifier: String, in workspace: MCPWorkspace) async throws -> MCPInAppReviewNotes {
        let app = try await workspace.app(matching: identifier)
        let content: InAppTextsContent
        do {
            content = try await workspace.services.storePage.inAppTexts(for: app)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s in-app purchases: \(error.localizedDescription)"))
        }
        let builder = InAppReviewNoteChangeBuilder(appID: app.id, content: content)
        var queued: [String: PendingChange] = [:]
        for change in workspace.changes.changes(for: app.id, section: .storePage) {
            if let productID = builder.productID(of: change) { queued[productID] = change }
        }
        return MCPInAppReviewNotes(app: app, content: content, builder: builder, queued: queued)
    }

    /// "SimProps · Review Notes · com.SimProps.complete".
    func target(_ productID: String) -> String {
        String(localized: "\(app.name) · Review Notes · \(productID)")
    }

    // MARK: - Reading

    /// Products App Store Connect has, so notes can be written to them.
    private var products: [InAppTextProduct] {
        content.products.filter { content.productResourceIDs[$0.id] != nil }
    }

    func json() -> JSONValue {
        [
            "appId": .string(app.id),
            "app": .string(app.name),
            "limit": ["max": .int(InAppReviewNoteChangeBuilder.limit), "unit": "characters"],
            "products": .array(products.map(json)),
        ]
    }

    private func json(_ product: InAppTextProduct) -> JSONValue {
        let live = content.reviewNotes[product.id] ?? ""
        let state = content.productStates[product.id]
        var json: [String: JSONValue] = [
            "productId": .string(product.id),
            "column": .string("\(product.id).reviewNote"),
            "name": .string(product.referenceName),
            "kind": product.kind == .subscription ? "subscription" : "inAppPurchase",
            "note": .string(queued[product.id]?.newValue ?? live),
            "writesTo": .string(Self.writesTo(state)),
        ]
        if let state { json["state"] = .string(state) }
        if let change = queued[product.id] {
            json["live"] = .string(live)
            json["queuedBy"] = .string(change.source.title)
            json["changeId"] = .string(change.id)
        }
        return .object(json)
    }

    /// Where an edit goes for a product in `state`.
    static func writesTo(_ state: String?) -> String {
        let state = state ?? ""
        if InAppReviewNoteChangeBuilder.lockedStates.contains(state) { return "locked: with App Review" }
        if InAppReviewNoteChangeBuilder.nextSubmissionStates.contains(state) { return "next review submission" }
        return "current"
    }

    // MARK: - Proposing

    /// An assistant's notes for one product: refused when over the limit,
    /// empty, for a product the app hasn't, the person's own unpushed
    /// notes, or a product with App Review.
    func propose(_ note: String, productID: String, source: ChangeSource, reason: String?) -> Outcome {
        let id = productID.hasSuffix(".reviewNote") ? String(productID.dropLast(".reviewNote".count)) : productID
        guard let product = products.first(where: { $0.id == id }) else {
            let known = products.map(\.id).joined(separator: ", ")
            let list = known.isEmpty ? String(localized: "it has none") : String(localized: "its products are \(known)")
            return .refused(code: "unknown_product", reason: String(localized: "\(app.name) has no product “\(id)”; \(list)."))
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .refused(code: "empty", reason: String(localized: "The notes are empty. Propose the notes themselves."))
        }
        guard note.count <= InAppReviewNoteChangeBuilder.limit else {
            let limit = InAppReviewNoteChangeBuilder.limit
            return .refused(code: "over_limit", reason: String(localized: "Over the limit: \(note.count) of \(limit) characters. Fix it and propose again."))
        }
        let state = content.productStates[id] ?? ""
        guard !InAppReviewNoteChangeBuilder.lockedStates.contains(state) else {
            let reason = String(localized: "\(product.id) is with App Review (\(state)), so its notes can’t change until review ends.")
            return .refused(code: "locked", reason: reason)
        }
        if let mine = queued[id], !mine.source.isAssistant, mine.newValue != note {
            let reason = String(localized: "The person already changed these notes; it waits in Review & Push. Leave it to them.")
            return .refused(code: "changed_by_person", reason: reason)
        }
        if note == queued[id]?.newValue { return .unchanged }
        if note == content.reviewNotes[id] ?? "" { return queued[id].map { .backToLive($0.id) } ?? .unchanged }
        guard let change = builder.change(product, to: note, source: source, reason: reason) else {
            return .refused(code: "unknown_product", reason: String(localized: "\(product.id) isn’t in App Store Connect yet."))
        }
        return .queued(change)
    }
}
