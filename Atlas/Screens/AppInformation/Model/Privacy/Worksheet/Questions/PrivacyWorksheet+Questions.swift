//
//  PrivacyWorksheet+Questions.swift
//  Atlas
//

import Foundation

// Answering the assistant's open questions. The answer is the person's, so
// what the assistant said it means for the affected types counts at once
// (the label preview "updates as you answer"), and the first question
// follows: a type that becomes collected can't sit under "No".
extension PrivacyWorksheet {
    /// Answers an open question, or changes its answer, and applies what
    /// the assistant said that answer means:
    /// - the affected types take the answer's effect as the person's own:
    ///   an unreviewed suggestion it confirms is accepted, one it changes is
    ///   "Edited by you", a type nobody answered becomes theirs;
    /// - an effect with only a summary ("Data Not Collected stays correct.")
    ///   leaves the types as they were before the question was answered;
    /// - the first question turns Yes when an affected type becomes
    ///   collected, and goes back to what it was when a changed answer
    ///   leaves nothing collected.
    mutating func answerQuestion(_ id: String, with answer: Bool) {
        guard let index = questions.firstIndex(where: { $0.id == id }) else { return }
        let question = questions[index]
        let baseline: PrivacyQuestionBaseline
        if let saved = question.baseline {
            baseline = saved
            for type in question.affects {
                entries[type] = saved.entries[type]
            }
        } else {
            baseline = PrivacyQuestionBaseline(entries: entries.filter { question.affects.contains($0.key) }, collects: collects)
        }
        questions[index].answer = answer
        questions[index].baseline = baseline
        if let effect = question.effect(of: answer)?.answer {
            for type in question.affects {
                settle(type, as: effect)
            }
        }
        followFirstQuestion(after: question, from: baseline)
    }

    /// The types an answered question gave an answer, e.g. [.purchases] for
    /// "Yes: Purchase History is collected". Empty while it's open or when
    /// the answer's effect only has a summary.
    func typesChanged(by question: PrivacyOpenQuestion) -> [PrivacyDataType] {
        guard let answer = question.answer, question.effect(of: answer)?.answer != nil else { return [] }
        return question.affects
    }

    /// Worksheets saved before answers counted: answering only rewrote the
    /// unreviewed suggestions, which stayed unreviewed (left out of the
    /// label), and never touched the first question. Settles those answers
    /// as the person's, the first question with them, and records the
    /// baseline (the assistant's suggestion as it was) for a changed answer.
    mutating func settleAnswersSavedWithoutBaseline() {
        for index in questions.indices {
            let question = questions[index]
            guard let answer = question.answer, question.baseline == nil else { continue }
            var before: [PrivacyDataType: PrivacyTypeEntry] = [:]
            for type in question.affects {
                guard let entry = entries[type] else { continue }
                if entry.status == .unreviewed, let suggestion = entry.suggestion {
                    before[type] = .suggested(suggestion)
                } else {
                    before[type] = entry
                }
            }
            let baseline = PrivacyQuestionBaseline(entries: before, collects: collects)
            questions[index].baseline = baseline
            guard let effect = question.effect(of: answer)?.answer else { continue }
            for type in question.affects where entries[type]?.status == .unreviewed && entries[type]?.answer == effect {
                settle(type, as: effect)
            }
            followFirstQuestion(after: question, from: baseline)
        }
    }

    // MARK: - Private

    /// `type` takes `answer` because the person answered a question.
    private mutating func settle(_ type: PrivacyDataType, as answer: PrivacyAnswer) {
        guard var entry = entries[type] else {
            if answer.collected { entries[type] = .yours(answer) }
            return
        }
        if entry.status == .unreviewed {
            entry.answer = answer
            entry.status = entry.suggestion?.answer == answer ? .accepted : .edited
        } else {
            entry.edit(answer)
        }
        if entry.conflict?.answer == answer { entry.conflict = nil }
        entries[type] = entry
    }

    /// Yes once one of the question's types counts as collected; back to the
    /// baseline's answer when nothing in the worksheet is collected any more.
    private mutating func followFirstQuestion(after question: PrivacyOpenQuestion, from baseline: PrivacyQuestionBaseline) {
        if question.affects.contains(where: { entries[$0]?.countedAnswer?.collected == true }) {
            if collects?.countedValue != true { setCollects(true) }
            return
        }
        let anyCollected = entries.values.contains { $0.answer.collected }
        if !anyCollected, collects?.value == true, baseline.collects?.value != true {
            collects = baseline.collects
        }
    }
}
