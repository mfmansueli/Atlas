//
//  NativeTranslationDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Texts in several languages, one native-speaker agent per language
/// (`NativeTranslationDebugData`):
/// - `tr-native-run`: Overview while it works, “Translating · 1 of 4
///   languages”.
/// - `tr-native-store`: French on the Store Page, its suggestions in
///   while Japanese and Portuguese (Brazil) are still coming.
/// - `tr-native-done`: the last reviewer ends its language a moment after
///   the scene appears, and the run finishes with its toast.
enum NativeTranslationDebugScenes {
    static let ids = ["tr-native-run", "tr-native-store", "tr-native-done"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "tr-native-run":
            return overview(NativeTranslationDebugData.store(.working))
        case "tr-native-store":
            return SuggestionsDebugScenes.storePage(.connected, store: NativeTranslationDebugData.store(.working)) { $0.openEditor(.french) }
        case "tr-native-done":
            let store = NativeTranslationDebugData.store(.lastInReview)
            return AnyView(overview(store).modifier(EndsLast(store: store)))
        default:
            return nil
        }
    }

    @MainActor
    private static func overview(_ store: FieldSuggestionStore) -> AnyView {
        SuggestionsDebugScenes.with(.connected, DebugMainScene(section: .overview, suggestions: store))
    }

    /// Ends the last language a moment after the scene appears, as its
    /// reviewer would.
    private struct EndsLast: ViewModifier {
        let store: FieldSuggestionStore

        func body(content: Content) -> some View {
            content.task {
                try? await Task.sleep(for: .seconds(1))
                NativeTranslationDebugData.endLast(in: store)
            }
        }
    }
}
#endif
