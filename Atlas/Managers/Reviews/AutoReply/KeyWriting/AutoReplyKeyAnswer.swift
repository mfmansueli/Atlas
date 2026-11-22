//
//  AutoReplyKeyAnswer.swift
//  Atlas
//

import Foundation

/// The replies in the model's answer to `AutoReplyKeyPrompt`:
/// `{"replies": […]}`, even inside a ```json fence or after a sentence.
struct AutoReplyKeyAnswer: Decodable, Equatable {
    struct Reply: Decodable, Equatable {
        var reviewId: String
        var text: String
        var meaning: String?
        var waitTopics: [String]?
        var unsure: Bool?

        /// Unknown topic names are left out.
        var topics: Set<AutoReplyTopic> { Set((waitTopics ?? []).compactMap(AutoReplyTopic.init(rawValue:))) }
    }

    var replies: [Reply]

    static func parse(_ text: String, vendor: AIProviderVendor) throws -> [Reply] {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let answer = try? JSONDecoder().decode(Self.self, from: Data(text[start...end].utf8))
        else { throw AIProviderError.unreadableResponse(vendor) }
        return answer.replies
    }
}
