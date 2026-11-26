//
//  AppInformationViewModel+AcceptAll.swift
//  Atlas
//

import Foundation

// The top of the section: how many suggestions wait on each page, Accept n
// on This Page, and Accept All Pages, which shows them first unless the
// person said not to.
extension AppInformationViewModel {
    /// Every page's suggestions, in the strip's order.
    private var allPageSuggestions: [FieldSuggestion] {
        Self.slotPages.flatMap { visibleSuggestions(on: $0) }
    }

    func pageBarModel(on page: AppInformationPage, acceptsRightAway: Bool) -> AppInformationPageBarModel {
        let others = Self.slotPages.filter { $0 != page && !visibleSuggestions(on: $0).isEmpty }
        return AppInformationPageBarModel(
            hereCount: visibleSuggestions(on: page).count,
            totalCount: allPageSuggestions.count,
            otherPageCount: others.count,
            acceptsRightAway: acceptsRightAway
        )
    }

    /// What Accept All Pages offers, the open page first in focus.
    func acceptAllSelection() -> AcceptAllSelection {
        let groups = Self.slotPages.compactMap { page -> AcceptAllGroup? in
            let items = visibleSuggestions(on: page).compactMap { suggestion -> AcceptAllItem? in
                guard let slot = slot(of: suggestion) else { return nil }
                var title = slot.title
                if case let .accessibility(family, _) = slot { title = "\(family.name) · \(title)" }
                return AcceptAllItem(
                    id: suggestion.id,
                    title: title,
                    source: suggestion.source,
                    current: slot.displayValue(suggestionValue(slot)),
                    suggested: slot.displayValue(suggestion.value),
                    reason: suggestion.reason
                )
            }
            guard !items.isEmpty else { return nil }
            return AcceptAllGroup(id: page.rawValue, title: page.title, items: items)
        }
        return AcceptAllSelection(kind: .appInformation, groups: groups, focus: page.rawValue)
    }

    /// "Accept n on This Page".
    func acceptSuggestions(onPage page: AppInformationPage) {
        let batch = visibleSuggestions(on: page)
        let text = batch.count == 1
            ? String(localized: "Accepted 1 on \(page.title). In Review & Push.")
            : String(localized: "Accepted \(batch.count) on \(page.title). In Review & Push.")
        accept(batch, toast: text)
    }

    /// The bar's button: right away when the person said not to ask,
    /// otherwise the sheet.
    func acceptAllPages(withoutAsking: Bool) {
        guard withoutAsking else {
            isAcceptAllPresented = true
            return
        }
        let batch = allPageSuggestions
        accept(batch, toast: AcceptAllKind.appInformation.acceptedText(batch.count, groups: pageCount(of: batch), withoutAsking: true))
    }

    /// The sheet's Accept: only what was left ticked.
    func acceptSuggestions(ids: Set<String>, turnedOffAsking: Bool) {
        let batch = allPageSuggestions.filter { ids.contains($0.id) }
        accept(batch, toast: AcceptAllKind.appInformation.acceptedText(batch.count, groups: pageCount(of: batch), turnedOffAsking: turnedOffAsking))
    }

    private func pageCount(of batch: [FieldSuggestion]) -> Int {
        Set(batch.compactMap(\.target.scope.page)).count
    }
}
