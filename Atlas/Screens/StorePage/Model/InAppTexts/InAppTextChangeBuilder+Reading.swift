//
//  InAppTextChangeBuilder+Reading.swift
//  Atlas
//

import Foundation

extension InAppTextChangeBuilder {
    /// Lays queued in-app text changes onto a matrix with App Store
    /// Connect's values: an assistant's change stays its proposal (so the
    /// tag survives your next edit), anything else is your edit.
    func apply(_ changes: [PendingChange], to matrix: inout InAppTextMatrix) {
        for change in changes where owns(change) {
            guard let document = StorePageWriteDocument.decode(change.requests.first?.body),
                  let (owner, locale) = target(of: change, document: document)
            else { continue }
            for column in matrix.columns where column.productID == owner.productID {
                let attribute = column.field.isDescription ? "description" : "name"
                guard document.data.attributes.keys.contains(attribute) else { continue }
                let text = document.attribute(attribute) ?? ""
                guard text != matrix.value(column, in: locale) else { continue }
                if case let .assistant(client) = change.source {
                    _ = matrix.propose(text, for: column, in: locale, by: client)
                } else {
                    matrix.edit(column, in: locale, to: text)
                }
            }
        }
    }

    /// The owner from the id, the locale from the body (new) or the id. The
    /// owner is matched as a prefix: a resource ID may hold dots (the
    /// sample data's "resource-lumen.plus.annual"), and splitting on them
    /// lost every product edit when the queue refreshed the cells.
    private func target(of change: PendingChange, document: StorePageWriteDocument) -> (Owner, StoreLocale)? {
        let rest = String(change.id.dropFirst(idPrefix.count))
        guard let owner = owners.first(where: { rest.hasPrefix($0.idComponent + ".") }) else { return nil }
        let parts = rest.dropFirst(owner.idComponent.count + 1).split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        let code = document.attribute("locale") ?? parts[0]
        guard let locale = StoreLocaleCatalog.locale(code: code) else { return nil }
        return (owner, locale)
    }
}
