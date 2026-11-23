//
//  SuggestionLayers+MCP.swift
//  Atlas
//

import Foundation

extension SuggestionLayers {
    /// `details`, `confidence` and `gloss` as the get_ tools list them
    /// beside a suggestion's reason; only those it has.
    var mcpFields: [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        if let details { fields["details"] = .string(details) }
        if let confidence { fields["confidence"] = .int(confidence.rawValue) }
        if let gloss { fields["gloss"] = .string(gloss) }
        return fields
    }

    /// Puts them into a get_ tool's entry for the suggestion.
    func add(to entry: inout [String: JSONValue]) {
        entry.merge(mcpFields) { _, new in new }
    }
}
