//
//  AssistantTextCheck.swift
//  Atlas
//

import Foundation

/// Checks a call's card texts against `AssistantTextLimits` before the tool
/// runs, the same way for every tool: wherever the tool's input schema has a
/// free-text `why`, `reason` or `rationale` (the card's why line), a `details`, a `gloss`, a `means` or `naturalMeans`, or a numeric
/// `confidence`, at any depth (a batch's items too), the value sent there is
/// checked. A text that's too long refuses the whole call with the place and
/// the reason, e.g. "items[2].why is 164 characters; at most 110. Move the
/// rest to details.", so the assistant rewrites it and sends it again.
enum AssistantTextCheck {
    /// The first text over its limit, or nil when the call can run.
    static func refusal(_ arguments: [String: JSONValue], schema: JSONValue) -> String? {
        refusal(in: arguments, schema: schema, path: "")
    }

    private static func refusal(in object: [String: JSONValue], schema: JSONValue, path: String) -> String? {
        guard let properties = schema["properties"]?.objectValue else { return nil }
        let hasDetails = properties["details"] != nil
        for key in object.keys.sorted() {
            guard let value = object[key], let property = properties[key] else { continue }
            let field = path + key
            if let refusal = check(value, key: key, property: property, field: field, hasDetails: hasDetails) { return refusal }
            if let refusal = nested(value, property: property, field: field) { return refusal }
        }
        return nil
    }

    private static func check(_ value: JSONValue, key: String, property: JSONValue, field: String, hasDetails: Bool) -> String? {
        if key == "confidence" {
            return property["type"]?.stringValue == "integer" ? AssistantTextLimits.confidenceRefusal(value, field: field) : nil
        }
        guard property["type"]?.stringValue == "string", property["enum"] == nil, let text = value.stringValue else { return nil }
        switch key {
        case "why", "reason", "rationale": return AssistantTextLimits.whyRefusal(text, field: field, hasDetails: hasDetails)
        case "details": return AssistantTextLimits.detailsRefusal(text, field: field)
        case "gloss": return AssistantTextLimits.glossRefusal(text, field: field)
        case "means", "naturalMeans": return AssistantTextLimits.meansRefusal(text, field: field)
        default: return nil
        }
    }

    /// An object property, or a list of objects, checked like the call.
    private static func nested(_ value: JSONValue, property: JSONValue, field: String) -> String? {
        if let object = value.objectValue, property["properties"] != nil {
            return refusal(in: object, schema: property, path: field + ".")
        }
        guard let items = value.arrayValue, let itemSchema = property["items"], itemSchema["properties"] != nil else { return nil }
        for (index, item) in items.enumerated() {
            guard let object = item.objectValue else { continue }
            if let refusal = refusal(in: object, schema: itemSchema, path: "\(field)[\(index)].") { return refusal }
        }
        return nil
    }
}
