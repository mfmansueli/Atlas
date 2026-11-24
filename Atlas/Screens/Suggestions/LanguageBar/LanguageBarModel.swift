//
//  LanguageBarModel.swift
//  Atlas
//

import Foundation

/// What the language picker and the bar around it show (README-DS §12:
/// one picker, not tabs): the language in view with its count, Accept All
/// Languages, the arrows to the languages with suggestions, and the menu of
/// every language, grouped. Store Page, Screenshots, In-App Events and
/// Product Pages show the whole bar; a narrow place (Overview's App Store
/// preview) or a switch that doesn't count suggestions (Retention, the
/// Autopilot studio) shows only the picker.
struct LanguageBarModel: Equatable, Sendable {
    var entries: [LanguageBarEntry]
    var current: StoreLocale
    /// "Don't ask again" is on: Accept All Languages accepts at once.
    var acceptsRightAway = false
    /// Accept All Languages shows every suggestion first unless "Don't ask
    /// again" is on (Store Page, Screenshots). False where it always
    /// accepts at once, with Undo in its toast (In-App Events, Product
    /// Pages): its menu row has no "…" and the bar no "Accepts right away".
    var acceptAllShowsSuggestionsFirst = true
    /// The menu groups the languages by what's left to review. False for a
    /// switch with nothing to review: one list, no ✓, no Accept All.
    var countsSuggestions = true
    /// The menu's last group, for the languages that show the primary
    /// one's content with nothing to review: "Uses English (U.S.)
    /// screenshots". Nil: they stay under Up to date.
    var reuseGroupTitle: String?

    var currentEntry: LanguageBarEntry? { entries.first { $0.locale == current } }
    var hereCount: Int { currentEntry?.count ?? 0 }
    var totalCount: Int { entries.reduce(0) { $0 + $1.count } }
    var withSuggestions: [LanguageBarEntry] { entries.filter { $0.count > 0 } }
    var upToDate: [LanguageBarEntry] { entries.filter { $0.count == 0 } }
    private var others: [LanguageBarEntry] { withSuggestions.filter { $0.locale != current } }

    /// "5 suggestions here", under the language's name.
    var hereText: String {
        switch hereCount {
        case 0: String(localized: "Nothing to review here")
        case 1: String(localized: "1 suggestion here")
        default: String(localized: "\(hereCount) suggestions here")
        }
    }

    /// "27 more in 5 other languages", beside the arrows. Nothing once
    /// every language is reviewed: the button beside it says so (Alba's bar
    /// said it three times, with "Nothing to review here").
    var restText: String {
        if !others.isEmpty {
            let count = totalCount - hereCount
            return others.count == 1
                ? String(localized: "\(count) more in 1 other language")
                : String(localized: "\(count) more in \(others.count) other languages")
        }
        return totalCount > 0 ? String(localized: "Only this language has suggestions") : ""
    }

    var acceptAllTitle: String {
        totalCount > 0 ? String(localized: "Accept All Languages") : String(localized: "All Languages Reviewed")
    }

    /// Accept All Languages shows nothing first.
    private var acceptsAtOnce: Bool { acceptsRightAway || !acceptAllShowsSuggestionsFirst }

    /// The menu's last row: it says when it will ask first.
    var menuAcceptAllTitle: String {
        acceptsAtOnce ? String(localized: "Accept All Languages") : String(localized: "Accept All Languages…")
    }

    /// "Accepts right away" and Ask First under the bar: only where Accept
    /// All Languages would otherwise show the suggestions first.
    var showsAcceptsRightAway: Bool {
        acceptsRightAway && acceptAllShowsSuggestionsFirst && totalCount > 0
    }

    var acceptAllAccessibilityText: String {
        guard totalCount > 0 else { return String(localized: "Every language is reviewed") }
        let how = acceptsAtOnce ? String(localized: "accepts right away") : String(localized: "shows them first")
        return String(localized: "Accept all languages: \(totalCount) suggestions in \(withSuggestions.count) languages, \(how)")
    }

    /// "Accept 5 in English".
    var acceptHereTitle: String {
        String(localized: "Accept \(hereCount) in \(Self.shortName(current))")
    }

    var pickerAccessibilityText: String {
        guard countsSuggestions else { return String(localized: "Language: \(current.name). Choose another language.") }
        return String(localized: "Language: \(current.name). \(hereText). Choose another language.")
    }

    /// The next language with suggestions, wrapping around.
    var next: StoreLocale? { neighbor(forward: true) }
    var previous: StoreLocale? { neighbor(forward: false) }

    private func neighbor(forward: Bool) -> StoreLocale? {
        guard let index = entries.firstIndex(where: { $0.locale == current }) else { return others.first?.locale }
        let after = entries[entries.index(after: index)...]
        let before = entries[..<index]
        let order = forward ? Array(after) + Array(before) : Array(before.reversed()) + Array(after.reversed())
        return order.first { $0.count > 0 }?.locale
    }

    /// The menu's languages for what was typed in Find a language: a name
    /// that contains it, a flag's region that is it ("DE"), or a code that
    /// starts with it ("pt"). Nothing typed matches every language.
    func matchingEntries(_ query: String) -> [LanguageBarEntry] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.locale.name.lowercased().contains(query)
                || entry.locale.regionCode.lowercased() == query
                || entry.locale.code.lowercased().hasPrefix(query)
        }
    }

    /// The menu for what was typed: Suggestions to review first, then Up
    /// to date, then the languages that use the primary one's content;
    /// typing keeps the groups, and a group with nothing in it goes. A
    /// switch that doesn't count suggestions shows one list.
    func menuGroups(matching query: String) -> [LanguageMenuGroup] {
        let shown = matchingEntries(query)
        guard countsSuggestions else {
            return shown.isEmpty ? [] : [LanguageMenuGroup(kind: .all, title: nil, entries: shown)]
        }
        let groupsReuse = reuseGroupTitle != nil
        let reuses = { (entry: LanguageBarEntry) in groupsReuse && entry.usesPrimary }
        let groups = [
            LanguageMenuGroup(kind: .toReview, title: String(localized: "Suggestions to review"), entries: shown.filter { $0.count > 0 }),
            LanguageMenuGroup(kind: .upToDate, title: String(localized: "Up to date"), entries: shown.filter { $0.count == 0 && !reuses($0) }),
            LanguageMenuGroup(kind: .usesPrimary, title: reuseGroupTitle, entries: shown.filter { $0.count == 0 && reuses($0) }),
        ]
        return groups.filter { !$0.entries.isEmpty }
    }

    /// "39 languages", beside Find a language.
    var countText: String {
        entries.count == 1 ? String(localized: "1 language", comment: "kind:description")
            : String(localized: "\(entries.count) languages", comment: "kind:description")
    }

    /// "English" for "English (U.S.)", in "Accept 5 in English". Never a
    /// region alone ("U.K."): a language is named in full everywhere else.
    static func shortName(_ locale: StoreLocale) -> String {
        locale.name.components(separatedBy: " (").first ?? locale.name
    }
}
