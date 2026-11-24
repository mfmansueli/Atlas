//
//  PrivacyDataType+MCP.swift
//  Atlas
//

import Foundation

extension PrivacyDataType {
    /// The entry in `get_privacy_questionnaire`'s `dataTypes`.
    var questionnaireJSON: JSONValue {
        [
            "id": .string(rawValue),
            "name": .string(name),
            "category": .string(category.name),
            "fastlaneKey": .string(fastlaneKey),
            "manifestKey": .string(manifestKey),
        ]
    }
}
