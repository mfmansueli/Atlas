//
//  DesignSourceSummary+MCP.swift
//  Atlas
//

import Foundation

/// What was found in a design project, as get_design_brief and
/// get_in_app_events give it: its title, colors, typefaces, logo and voice.
extension DesignSourceSummary {
    var mcpJSON: JSONValue {
        var found: [String: JSONValue] = [
            "title": .string(title),
            "colors": .array(colors.map { ["name": .string($0.name), "hex": .string($0.hex)] }),
        ]
        if let typefaces { found["typefaces"] = .string(typefaces) }
        if let logo { found["logo"] = .string(logo) }
        if let voice { found["voice"] = .string(voice) }
        return .object(found)
    }
}
