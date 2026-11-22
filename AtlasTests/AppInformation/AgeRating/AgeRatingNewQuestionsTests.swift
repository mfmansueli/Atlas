//
//  AgeRatingNewQuestionsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The questions App Store Connect added to `ageRatingDeclarations` after
/// the 2025 questionnaire: dating and relationships, shared location and
/// age-restricted social media. Yes/No capabilities that read and write
/// their own attributes and don't move the calculated rating.
@Suite("Age rating · newer questions")
struct AgeRatingNewQuestionsTests {
    private static let newer: [(AgeRatingQuestion, String)] = [
        (.datingAndRelationships, "datingAndRelationships"),
        (.sharedLocation, "sharedLocation"),
        (.socialMediaAgeRestricted, "socialMediaAgeRestricted"),
    ]

    @Test func eachIsAYesNoCapabilityWithItsAttribute() {
        for (question, key) in Self.newer {
            #expect(question.apiKey == key)
            #expect(question.group == .capabilities)
            #expect(question.answers == [.negative, .affirmative])
            #expect(!question.hasLevels)
            #expect(AgeRatingQuestionGroup.capabilities.questions.contains(question))
        }
    }

    @Test func aDeclarationReadsThem() {
        let answers = AgeRatingAnswers(attributes: [
            "datingAndRelationships": .bool(true),
            "sharedLocation": .bool(false),
            "socialMediaAgeRestricted": .bool(true),
        ])
        #expect(answers[.datingAndRelationships] == .affirmative)
        #expect(answers[.sharedLocation] == .negative)
        #expect(answers[.socialMediaAgeRestricted] == .affirmative)
    }

    @Test func aDeclarationWithoutThemLeavesThemUnanswered() {
        var values = AgeRatingValues()
        values.apiValues = ["socialMedia": .bool(true)]
        for (question, _) in Self.newer {
            #expect(!values.isAnswered(question), "\(question)")
        }
    }

    @Test func theyDontMoveTheCalculatedRating() {
        for (question, _) in Self.newer {
            var answers = AgeRatingAnswers()
            answers[question] = .affirmative
            #expect(AgeRatingCalculator.rating(for: answers) == .fourPlus, "\(question)")
        }
    }

    @Test func anAssistantNamesThemByIDOrAttribute() {
        #expect(AgeRatingQuestion.matching("datingAndRelationships") == .datingAndRelationships)
        #expect(AgeRatingQuestion.matching("SHAREDLOCATION") == .sharedLocation)
        #expect(AgeRatingQuestion.matching(" socialMediaAgeRestricted ") == .socialMediaAgeRestricted)
    }

    @Test func thePromptsAskAboutThem() {
        let text = MCPPrompt.fillAgeRating.message(app: "Lumen Journal")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(text.contains("dating and relationships"))
        #expect(text.contains("shared"))
        #expect(text.contains("restricted by age"))
    }
}
