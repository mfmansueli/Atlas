//
//  PrivacyWorksheet+MCP.swift
//  Atlas
//

import Foundation

extension PrivacyWorksheet {
    /// The worksheet as `get_privacy_questionnaire` returns it: the first
    /// question, each answered type with who answered and where it stands,
    /// the questions still open, and the person's answers to the others with
    /// the types each answer changed (already applied, as the person's).
    var questionnaireJSON: JSONValue {
        let answers: [JSONValue] = PrivacyDataType.allCases.compactMap { type in
            guard let entry = entries[type] else { return nil }
            var object = entry.answer.mcpJSON
            object["type"] = .string(type.rawValue)
            object["status"] = .string(entry.status.rawValue)
            object["answeredBy"] = .string(entry.client ?? "the person")
            if entry.conflict != nil { object["note"] = "Your earlier answer differs from the person's; they will pick one." }
            return .object(object)
        }
        return [
            "collects": collects.map { .bool($0.value) } ?? .null,
            "answers": .array(answers),
            "openQuestions": .array(openQuestions.map { ["id": .string($0.id), "question": .string($0.question)] }),
            "answeredQuestions": .array(questions.filter { !$0.isOpen }.map(answeredQuestionJSON)),
            "markedPublished": publication.map { .string($0.date.formatted(.iso8601)) } ?? .null,
        ]
    }

    /// `{id, question, answer, effect, changed}`: the person's answer and
    /// what it did, so a later scan builds on it instead of asking again.
    private func answeredQuestionJSON(_ question: PrivacyOpenQuestion) -> JSONValue {
        [
            "id": .string(question.id),
            "question": .string(question.question),
            "answer": question.answer.map { .bool($0) } ?? .null,
            "effect": question.effectSummary.map { .string($0) } ?? .null,
            "changed": .array(typesChanged(by: question).map { .string($0.rawValue) }),
        ]
    }
}
