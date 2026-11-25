//
//  PaywallDebugScene.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// One `pw-*` scene: the main window in Free with the paywall open over
/// it, in the state `PaywallDebugScenes` sets up.
struct PaywallDebugScene: View {
    let id: String
    @State private var model: PaywallModel
    @State private var isPresented = true

    init(id: String) {
        self.id = id
        _model = State(initialValue: PaywallModel(
            context: PaywallDebugScenes.context(for: id),
            entitlements: Entitlements(store: DebugProStore()),
            onContinue: PaywallDebugScenes.continues(id) ? {} : nil
        ))
    }

    var body: some View {
        DebugMainScene(section: PaywallDebugScenes.section(for: id), suggestions: SuggestionsDebugData.store(), isFree: true)
            .sheet(isPresented: $isPresented) {
                PaywallSheet(model: model) { _ in isPresented = false }
                    .task { await PaywallDebugScenes.prepare(model, for: id) }
            }
    }
}
#endif
