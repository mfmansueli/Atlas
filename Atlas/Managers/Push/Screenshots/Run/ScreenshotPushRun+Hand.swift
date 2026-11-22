//
//  ScreenshotPushRun+Hand.swift
//  Atlas
//

import Foundation

// A set changed by hand, once its uploads are done: the screenshots no
// place keeps are kept on this Mac and deleted (only when every upload of
// the set went and Apple processed it, so the set never ends with fewer
// screenshots than before by accident), then the set is put in the order
// the person left it.
extension ScreenshotPushRun {
    func finishHandSet(_ groupID: String) async {
        let indices = items.indices.filter { items[$0].groupID == groupID }
        let uploads = indices.filter { !items[$0].plan.content.isSetChange }
        let deletes = indices.filter { items[$0].plan.content == .delete && items[$0].status == .queued }
        let notDone = uploads.contains { !items[$0].isCommitted }
        let processing = uploads.contains { items[$0].isCommitted && !items[$0].isDeliveryConfirmed }
        for index in deletes {
            if let halt = haltStatus {
                items[index].status = halt
            } else if notDone {
                items[index].status = .notSent(String(localized: "Not deleted: an image in this set didn’t go, so nothing was taken out."))
            } else if processing {
                items[index].status = .notSent(String(localized: "Not deleted yet: Apple is still processing the new images. Push again in a few minutes."))
            } else {
                await deleteHandScreenshot(index)
            }
        }
        await reorderHand(groupID)
    }

    /// Keeps a copy of the item's live screenshot, then deletes it.
    func deleteHandScreenshot(_ index: Int) async {
        guard let old = items[index].plan.old else {
            items[index].status = .done
            return
        }
        let groupID = items[index].groupID
        do {
            try await keepCopy(index)
            if sets[groupID]?.order.contains(old.id) == true {
                _ = try await send(ScreenshotUploadRequests.delete(screenshotID: old.id))
                sets[groupID]?.order.removeAll { $0 == old.id }
            }
            items[index].isOldDeleted = true
            items[index].status = .done
        } catch {
            items[index].status = status(for: error, replaces: true)
        }
    }

    /// A full set changed by hand makes room with one of the screenshots it
    /// deletes. True when one went.
    func deleteOneForRoom(_ groupID: String) async -> Bool {
        guard sets[groupID]?.group.isHand == true,
              let index = items.indices.first(where: {
                  items[$0].groupID == groupID && items[$0].plan.content == .delete && items[$0].status == .queued
              }) else { return false }
        await deleteHandScreenshot(index)
        return items[index].status == .done
    }

    /// Puts the set in the order the person left it: each kept screenshot
    /// where it goes, each uploaded one in its place, anything else after.
    private func reorderHand(_ groupID: String) async {
        let orderItems = items.indices.filter { items[$0].groupID == groupID && items[$0].plan.content == .reorder }
        guard let progress = sets[groupID], let arrangement = progress.group.arrangement, let setID = progress.setID else {
            for index in orderItems where items[index].status == .queued {
                items[index].status = .failed(String(localized: "The set isn’t in App Store Connect."))
            }
            return
        }
        if let halt = haltStatus {
            for index in orderItems where items[index].status == .queued {
                items[index].status = halt
            }
            return
        }
        let desired = ScreenshotSetProgress.handOrder(arrangement, order: progress.order) { itemID in
            items.first { $0.id == itemID && $0.isCommitted }?.screenshotID
        }
        var failure: String?
        if desired != progress.order {
            do {
                _ = try await send(ScreenshotUploadRequests.reorder(setID: setID, screenshotIDs: desired))
                sets[groupID]?.order = desired
            } catch {
                failure = Self.describe(error)
                sets[groupID]?.note = String(localized: "The set couldn’t be put in order: \(Self.describe(error))")
            }
        }
        for index in orderItems where items[index].status == .queued {
            items[index].status = failure.map(ScreenshotUploadStatus.failed) ?? .done
        }
    }
}
