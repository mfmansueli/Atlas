//
//  DebugReviewData+ReviewNote.swift
//  Atlas
//

#if DEBUG
import Foundation

// "review-inapp-note": Claude Code's new Review Notes for Lumen Plus
// Lifetime, an in-app purchase whose release added weekly reflections.
extension DebugReviewData {
    static var reviewNoteChanges: [PendingChange] {
        let product = InAppTextProduct(id: "lumen.plus.lifetime", referenceName: "Lifetime", kind: .inAppPurchase)
        var content = InAppTextsContent.empty
        content.products = [product]
        content.productResourceIDs = [product.id: "6450200001"]
        content.reviewNotes = [product.id: "Buy it in Settings → Lumen Plus with a sandbox account. It unlocks unlimited photos."]
        content.productStates = [product.id: "APPROVED"]
        let builder = InAppReviewNoteChangeBuilder(appID: DebugFixtures.AppID.lumen, content: content)
        let note = "Buy it in Settings → Lumen Plus with a sandbox account. It unlocks unlimited photos and, since 1.5, weekly reflections."
        let change = builder.change(
            product,
            to: note,
            source: .assistant(client: "Claude Code"),
            reason: "1.5 adds weekly reflections to Lifetime. · git: WeeklyReflections.swift"
        )
        return change.map { [$0] } ?? []
    }
}
#endif
