//
//  InAppEventLanguageBar.swift
//  Atlas
//

import SwiftUI

/// Above an event's texts: the language bar (README-DS §12), with the
/// language picker, Accept All Languages, the arrows, how many wait in the
/// other languages, and Dismiss All at its end.
struct InAppEventLanguageBar: View {
    @Bindable var viewModel: InAppEventsViewModel
    let model: LanguageBarModel

    var body: some View {
        LanguageBar(model: model) { locale in
            viewModel.localeCode = locale.code
        } onAcceptAll: {
            viewModel.acceptAllLanguages()
        } onAcceptHere: {
            viewModel.acceptSuggestion()
        } trailing: {
            if viewModel.suggestedCount > 0 {
                Button("Dismiss All") {
                    viewModel.dismissAllLanguages()
                }
                .help("Dismisses this event’s suggested languages and revisions. You can undo.")
                .accessibilityLabel(Text("Dismiss All, \(viewModel.suggestedCount) suggested"))
                .accessibilityIdentifier("events.dismissAll")
            }
        }
    }
}
