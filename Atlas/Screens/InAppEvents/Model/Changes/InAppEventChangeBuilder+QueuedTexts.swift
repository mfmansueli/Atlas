//
//  InAppEventChangeBuilder+QueuedTexts.swift
//  Atlas
//

import Foundation

// The texts an event has waiting in Review & Push, per language, read
// back from the changes `fieldChange` and `newLanguageChange` queue (the
// person's edits and the suggestions they accepted alike).
extension InAppEventChangeBuilder {
    func queuedTexts(for eventID: String, in changes: [PendingChange]) -> [InAppEventQueuedTexts] {
        let prefix = "\(idPrefix)\(eventID)."
        var byLocale: [String: InAppEventQueuedTexts] = [:]
        for change in changes where owns(change) && change.id.hasPrefix(prefix) {
            let rest = change.id.dropFirst(prefix.count)
            guard let dot = rest.lastIndex(of: ".") else { continue }
            let locale = String(rest[..<dot])
            let last = String(rest[rest.index(after: dot)...])
            let texts: [InAppEventField: String]
            if last == Self.newSuffix {
                texts = InAppEventWriteDocument.decode(change.requests.first?.body)?.texts ?? [:]
            } else if let field = InAppEventField(rawValue: last) {
                texts = [field: change.newValue]
            } else {
                continue
            }
            var entry = byLocale[locale] ?? InAppEventQueuedTexts(
                locale: locale, changeIDs: [], isNewLanguage: false, texts: [:], sources: [], isAwaitingAcceptance: false
            )
            entry.changeIDs.append(change.id)
            entry.isNewLanguage = entry.isNewLanguage || last == Self.newSuffix
            entry.texts.merge(texts) { _, new in new }
            if !entry.sources.contains(change.source) { entry.sources.append(change.source) }
            entry.isAwaitingAcceptance = entry.isAwaitingAcceptance || change.awaitingAcceptance != nil
            byLocale[locale] = entry
        }
        return byLocale.values.sorted { $0.locale < $1.locale }
    }
}
