//
//  InAppEventWriteDocument.swift
//  Atlas
//

import Foundation

/// The JSON:API document that writes one language of an event: a `PATCH`
/// of one text, or the `POST` that creates the language with its texts.
struct InAppEventWriteDocument: Codable, Hashable, Sendable {
    struct Resource: Codable, Hashable, Sendable {
        var type: String
        var id: String?
        var attributes: [String: String]
        var relationships: [String: Relationship]?
    }

    struct Relationship: Codable, Hashable, Sendable {
        var data: Identifier
    }

    struct Identifier: Codable, Hashable, Sendable {
        var type: String
        var id: String
    }

    var data: Resource

    static let type = "appEventLocalizations"

    static func update(id: String, field: InAppEventField, value: String) -> InAppEventWriteDocument {
        InAppEventWriteDocument(data: Resource(type: type, id: id, attributes: [field.rawValue: value]))
    }

    static func create(eventID: String, locale: String, texts: [InAppEventField: String]) -> InAppEventWriteDocument {
        var attributes = ["locale": locale]
        for (field, value) in texts where !value.isEmpty {
            attributes[field.rawValue] = value
        }
        return InAppEventWriteDocument(data: Resource(
            type: type, attributes: attributes, relationships: ["appEvent": Relationship(data: Identifier(type: "appEvents", id: eventID))]
        ))
    }

    static func decode(_ body: Data?) -> InAppEventWriteDocument? {
        body.flatMap { try? JSONDecoder().decode(InAppEventWriteDocument.self, from: $0) }
    }

    /// The texts the document writes.
    var texts: [InAppEventField: String] {
        var texts: [InAppEventField: String] = [:]
        for field in InAppEventField.allCases {
            if let value = data.attributes[field.rawValue] { texts[field] = value }
        }
        return texts
    }
}
