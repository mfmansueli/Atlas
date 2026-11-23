//
//  ScreenshotsViewModel+HandProposals.swift
//  Atlas
//

import Foundation

// Files an assistant suggested for a screenshot (propose_screenshot_file),
// on the language page beside the suggested captions: Accept puts the file
// in its place like a replace by hand, Dismiss drops it.
extension ScreenshotsViewModel {
    /// The suggestions waiting for a language on a device.
    func handProposals(locale: String, displayType: ScreenshotDisplayType) -> [ScreenshotHandProposal] {
        (document?.handProposals ?? []).filter { $0.isWaiting && $0.locale == locale && $0.displayType == displayType }
    }

    /// Every suggested file waiting, for the section's count.
    var waitingHandProposals: Int {
        (document?.handProposals ?? []).count(where: \.isWaiting)
    }

    /// "Screenshot 3" or "A new screenshot", for the card.
    func handProposalTitle(_ proposal: ScreenshotHandProposal) -> String {
        guard let position = proposal.position else { return String(localized: "A new screenshot after the last one") }
        return String(localized: "Screenshot \(position + 1)")
    }

    func acceptHandProposal(_ proposal: ScreenshotHandProposal) async {
        guard var document else { return }
        let before = document
        var set = document.handSetOrStart(locale: proposal.locale, displayType: proposal.displayType, live: live)
        let isReplace = proposal.position.map { $0 < set.keptCount } ?? false
        let changed = if let position = proposal.position, isReplace {
            set.replace(position: position, with: proposal.file)
        } else {
            set.add([proposal.file]) > 0
        }
        guard changed else {
            notice = String(localized: "The set already has 10 screenshots. Delete one first, then accept it.")
            return
        }
        document.storeHandSet(set, live: live)
        decide(proposal.id, status: .accepted, in: &document)
        let text = isReplace
            ? String(localized: "Screenshot \(proposal.position.map { $0 + 1 } ?? 0) replaced with \(proposal.client)’s file. In Review & Push.")
            : String(localized: "\(proposal.client)’s screenshot added. In Review & Push.")
        await commit(document)
        handRevision += 1
        captionUndo = { [weak self] in
            await self?.commit(before)
            self?.handRevision += 1
        }
        captionToast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push"))
    }

    func dismissHandProposal(_ proposal: ScreenshotHandProposal) async {
        guard var document else { return }
        let before = document
        decide(proposal.id, status: .rejected, in: &document)
        await commit(document)
        captionUndo = { [weak self] in await self?.commit(before) }
        captionToast = ToastMessage(text: String(localized: "\(proposal.client)’s screenshot dismissed."), canUndo: true)
    }

    private func decide(_ id: String, status: ScreenshotProposalStatus, in document: inout ScreenshotsDocument) {
        guard var proposals = document.handProposals, let index = proposals.firstIndex(where: { $0.id == id }) else { return }
        proposals[index].status = status
        proposals[index].decidedAt = .now
        document.handProposals = proposals
    }
}
