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
}
