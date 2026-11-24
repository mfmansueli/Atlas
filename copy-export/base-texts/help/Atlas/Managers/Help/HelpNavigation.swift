//
//  HelpNavigation.swift
//  Atlas
//

import Observation

/// Where the Atlas Help window is: home, a search, or an article, with
/// Back, and the note after Show Me ("Opened Settings → Accounts in
/// Atlas").
@MainActor
@Observable
final class HelpNavigation {
    static let shared = HelpNavigation()

    enum Place: Hashable {
        case home
        case search(String)
        case article(String)
    }

    private(set) var place: Place = .home
    private(set) var history: [Place] = []
    /// The search field's text.
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            place = trimmed.isEmpty ? .home : .search(trimmed)
        }
    }

    /// What Show Me last opened.
    var shown: String?

    var canGoBack: Bool { !history.isEmpty }

    func open(_ articleID: String) {
        guard place != .article(articleID) else { return }
        history.append(place)
        place = .article(articleID)
        shown = nil
    }

    func goHome() {
        guard place != .home else { return }
        history.append(place)
        setQuietly("")
        place = .home
        shown = nil
    }

    func back() {
        guard let previous = history.popLast() else { return }
        place = previous
        if case let .search(text) = previous { setQuietly(text) } else { setQuietly("") }
        shown = nil
    }

    private func setQuietly(_ text: String) {
        let place = place
        query = text
        self.place = place
    }
}
