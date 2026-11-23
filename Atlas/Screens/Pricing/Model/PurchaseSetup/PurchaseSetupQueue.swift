//
//  PurchaseSetupQueue.swift
//  Atlas
//

import Foundation

/// Queues an introductory offer or App Review screenshot for a target, the
/// same way from Pricing's sheets and the assistants' tools: its own change
/// for a product App Store Connect has, one more step of the queued change
/// for a new one.
@MainActor
struct PurchaseSetupQueue {
    let app: StoreApp
    let queue: ChangeQueue
    var folder: PurchaseReviewScreenshotFolder = .shared

    /// The change that now carries the offer; nil when the queued product
    /// left Review & Push.
    @discardableResult
    func queueIntroductoryOffer(
        _ offer: NewIntroductoryOffer,
        for target: PurchaseSetupTarget,
        problems: [IntroductoryOfferProblem] = [],
        source: ChangeSource,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange.ID? {
        switch target.place {
        case let .existing(product):
            let change = IntroductoryOfferChangeBuilder(app: app).change(
                for: offer, subscription: product, problems: problems, source: source, evidence: evidence, at: date
            )
            queue.upsert(change)
            return change.id
        case let .queued(id):
            guard let change = queue.change(id: id) else { return nil }
            queue.upsert(IntroductoryOfferChangeBuilder.attaching(offer, to: change, source: source))
            return id
        }
    }

    /// The change that now carries the screenshot; nil when the queued
    /// product left Review & Push.
    @discardableResult
    func queueReviewScreenshot(
        _ file: PurchaseReviewScreenshotFile,
        for target: PurchaseSetupTarget,
        current: PurchaseReviewScreenshotState? = nil,
        source: ChangeSource,
        at date: Date = .now
    ) -> PendingChange.ID? {
        let builder = PurchaseReviewScreenshotChangeBuilder(app: app, folder: folder)
        switch target.place {
        case let .existing(product):
            let change = builder.change(for: file, product: product, current: current, source: source, at: date)
            queue.upsert(change)
            return change.id
        case let .queued(id):
            guard let change = queue.change(id: id) else { return nil }
            queue.upsert(builder.attaching(file, owner: target.owner, to: change, source: source))
            return id
        }
    }

    /// The offer waiting for the target, if one is.
    func queuedIntroductoryOffer(for target: PurchaseSetupTarget) -> NewIntroductoryOffer? {
        change(carrying: target, prefix: IntroductoryOfferChangeBuilder.changeID).flatMap(IntroductoryOfferChangeBuilder.offer(in:))
    }

    /// The screenshot upload waiting for the target, if one is.
    func queuedReviewScreenshot(for target: PurchaseSetupTarget) -> PurchaseReviewScreenshotPush? {
        change(carrying: target, prefix: PurchaseReviewScreenshotChangeBuilder.changeID).flatMap(PurchaseReviewScreenshotChangeBuilder.screenshot(in:))
    }

    private func change(carrying target: PurchaseSetupTarget, prefix: (StoreApp.ID, String) -> PendingChange.ID) -> PendingChange? {
        switch target.place {
        case .existing: queue.change(id: prefix(app.id, target.productID))
        case let .queued(id): queue.change(id: id)
        }
    }

    /// A new product's change proposed again: the offer and screenshot the
    /// old one carried stay unless the new one brings its own.
    static func carryingExtras(from old: PendingChange?, into new: PendingChange) -> PendingChange {
        guard let old else { return new }
        var new = new
        let extras: [(fieldID: String, isStep: (PushRequest) -> Bool)] = [
            (IntroductoryOfferChangeBuilder.fieldID, { IntroductoryOfferEverywhere($0) != nil }),
            (PurchaseReviewScreenshotChangeBuilder.fieldID, { PurchaseReviewScreenshotPush($0) != nil }),
        ]
        for extra in extras where !new.requests.contains(where: extra.isStep) {
            new.requests += old.requests.filter(extra.isStep)
            if let field = old.creation?.fields.first(where: { $0.id == extra.fieldID }) { new.creation?.fields.append(field) }
        }
        return new
    }

    /// Whether a change creates a product or sets one up (an offer, a
    /// review screenshot), rather than changing prices.
    static func isSetup(_ change: PendingChange) -> Bool {
        NewSubscriptionChangeBuilder.owns(change) || NewInAppPurchaseChangeBuilder.owns(change)
            || IntroductoryOfferChangeBuilder.owns(change) || PurchaseReviewScreenshotChangeBuilder.owns(change)
            || SubscriptionOfferChanges.owns(change)
    }
}
