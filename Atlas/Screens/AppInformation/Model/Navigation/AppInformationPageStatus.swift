//
//  AppInformationPageStatus.swift
//  Atlas
//

import Foundation

/// A page's state on its card in App Information's strip (board 88), in
/// this order: what the assistant brought, then what only the person can
/// give, then Ready.
///
/// - "3 suggested", purple: suggestions wait on the page.
/// - "2 need you", amber: nothing is suggested, but something is still the
///   person's to give (`AppInformationNeedsYou`): an empty field Apple
///   requires, an unanswered question, a compliance answer, App Privacy's
///   worksheet.
/// - "Ready", green: neither.
/// - While the page loads, a grey skeleton line; "Couldn’t load", amber,
///   when it failed with nothing to show.
struct AppInformationPageStatus: Hashable, Sendable {
    enum State: Hashable, Sendable {
        case loading
        case failed
        case suggested(Int)
        case needsYou(Int)
        case ready
    }

    let state: State

    init(_ state: State) {
        self.state = state
    }

    /// Suggestions come first: accepting them is the page's next step, and
    /// often answers what needs the person too.
    init(isLoaded: Bool, hasFailed: Bool = false, suggested: Int, needsYou: Int) {
        if !isLoaded {
            state = hasFailed ? .failed : .loading
        } else if suggested > 0 {
            state = .suggested(suggested)
        } else if needsYou > 0 {
            state = .needsYou(needsYou)
        } else {
            state = .ready
        }
    }

    /// The card's status line; nil while loading.
    var text: String? {
        switch state {
        case .loading: nil
        case .failed: String(localized: "Couldn’t load", comment: "kind:status · App Information page card, the page failed to load")
        case let .suggested(count): String(localized: "\(count) suggested", comment: "kind:status · App Information page card, suggestions waiting")
        case .needsYou(1): String(localized: "1 needs you", comment: "kind:status · App Information page card, one thing only the person can give")
        case let .needsYou(count): String(localized: "\(count) need you", comment: "kind:status · App Information page card, things only the person can give")
        case .ready: String(localized: "Ready", comment: "kind:status · App Information page card, nothing left")
        }
    }

    /// Purple for suggestions, amber for the person, green when ready.
    var tone: PageCardTone {
        switch state {
        case .loading: .neutral
        case .failed, .needsYou: .warning
        case .suggested: .ai
        case .ready: .ok
        }
    }

    var isLoading: Bool { state == .loading }

    var isReady: Bool { state == .ready }
}
