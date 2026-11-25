//
//  SuggestedText.swift
//  Atlas
//

import SwiftUI

/// A suggestion's text (effect 3, README — Design system §7): when the
/// suggestion lands while the person looks, its words come in from a light
/// blur (`ArrivingText`), together with the card's arrival; otherwise, and
/// once they have arrived, it's plain text. Freshness is the card's own
/// (`ArrivalLedger`, same key and date), read before the card claims it.
/// `marks`: phrases that read like a translation (board 77), underlined in
/// amber once the words have arrived, with `markHelp` as the tooltip.
struct SuggestedText: View {
    let text: String
    var marks: [String] = []
    var markHelp: String = ""

    @State private var arrives: Bool

    init(_ text: String, arrivalKey: String, arrivedAt: Date?, marks: [String] = [], markHelp: String = "", ledger: ArrivalLedger = .shared) {
        self.text = text
        self.marks = marks
        self.markHelp = markHelp
        _arrives = State(initialValue: Self.isArriving(arrivalKey: arrivalKey, arrivedAt: arrivedAt, ledger: ledger))
    }

    var body: some View {
        if arrives {
            ArrivingText(text)
                .task {
                    let words = ArrivingText.words(in: text).count
                    try? await Task.sleep(for: .seconds(ArrivingText.duration(wordCount: words) + 0.1))
                    arrives = false
                }
        } else if marks.isEmpty {
            Text(text)
        } else {
            Text(TranslationMarks.marked(text, phrases: marks))
                .help(markHelp)
        }
    }

    /// Whether the text arrives: only for a fresh suggestion.
    static func isArriving(arrivalKey: String, arrivedAt: Date?, ledger: ArrivalLedger = .shared) -> Bool {
        ledger.isFresh(key: arrivalKey, arrivedAt: arrivedAt)
    }
}

#Preview {
    SuggestedText("Private diary, mood & prompts", arrivalKey: "preview", arrivedAt: .now)
        .padding()
}
