//
//  MCPToolArguments+Layers.swift
//  Atlas
//

import Foundation

extension MCPToolArguments {
    /// `details`, `confidence` and `gloss` as sent beside a why, or nil when
    /// none came. The server checked their limits before the call
    /// (`AssistantTextCheck`); a confidence outside 1–3 still throws here
    /// for a call that didn't come through it.
    func layers() throws -> SuggestionLayers? {
        let confidence: HowSure?
        if let number = try optionalInt("confidence") {
            guard let value = HowSure(rawValue: number) else {
                throw MCPToolError.invalidArgument(name: "confidence", expected: String(localized: "1, 2 or 3"))
            }
            confidence = value
        } else {
            confidence = nil
        }
        return try SuggestionLayers(details: optionalString("details"), confidence: confidence, gloss: optionalString("gloss")).nonEmpty
    }

    /// A batch item's own layers over the call's: its details and how sure
    /// win, else the call's; a gloss is only ever its own, since it says
    /// what that item's text means.
    func layers(over call: SuggestionLayers?) throws -> SuggestionLayers? {
        let own = try layers()
        return SuggestionLayers(
            details: own?.details ?? call?.details, confidence: own?.confidence ?? call?.confidence, gloss: own?.gloss
        ).nonEmpty
    }
}
