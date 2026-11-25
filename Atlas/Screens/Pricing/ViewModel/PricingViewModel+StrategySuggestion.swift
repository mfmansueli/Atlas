//
//  PricingViewModel+StrategySuggestion.swift
//  Atlas
//

import Foundation

/// A strategy or mode an assistant suggested (`propose_pricing_strategy`):
/// the card at the top of Pricing with Now and New, Dismiss and Accept.
/// Accepting changes Atlas's own setting, as Customize… and the mode menu
/// do (a toast offers Undo); nothing is pushed.
extension PricingViewModel {
    /// The suggestion waiting for this app, while it still changes something.
    var strategySuggestion: PricingStrategySuggestion? {
        guard let suggestion = modes.strategySuggestion(for: app.id),
              suggestion.changes(mode: mode, strategy: strategy.strategy) else { return nil }
        return suggestion
    }

    func strategyComparison(for suggestion: PricingStrategySuggestion) -> PricingStrategyComparison {
        PricingStrategyComparison(mode: mode, strategy: strategy.strategy, suggestion: suggestion)
    }

    /// Accept: the strategy and mode become the app's, as if set by hand.
    func acceptStrategySuggestion() async {
        guard let suggestion = strategySuggestion else { return }
        let previousStrategy = strategy.strategy
        let previousMode = mode
        modes.removeStrategySuggestion(for: app.id)
        if let new = suggestion.strategy, new != previousStrategy {
            strategy.replace(with: new)
            strategyDidChange()
        }
        if let newMode = suggestion.mode, newMode != previousMode {
            await setMode(newMode)
        }
        toastUndo = { [weak self] in
            guard let self else { return }
            strategy.replace(with: previousStrategy)
            strategyDidChange()
            if mode != previousMode { apply(mode: previousMode) }
            modes.suggestStrategy(suggestion, for: app.id)
        }
        toast = ToastMessage(text: String(localized: "Pricing strategy changed for \(app.name).", comment: "kind:toast"), canUndo: true)
    }

    /// Dismiss: the app keeps its strategy and mode.
    func dismissStrategySuggestion() {
        modes.removeStrategySuggestion(for: app.id)
    }
}
