//
//  AppInformationPageCardsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The page strip's cards (board 88): the seven pages in order, "Only
/// Apple sees" before App Review, and each card's status and colour.
@Suite("AppInformationPageCards")
struct AppInformationPageCardsTests {
    private let ready = AppInformationPageStatus(isLoaded: true, suggested: 0, needsYou: 0)

    @Test func theSevenPagesInTheStripsOrder() {
        let items = AppInformationPageCards.items { _ in ready }
        #expect(items.map(\.id) == [.general, .appCompliance, .ageRating, .accessibility, .appPrivacy, .appReview, .exportCompliance])
        #expect(items.map(\.title) == ["General", "App Compliance", "Age Rating", "Accessibility", "App Privacy", "App Review", "Export Compliance"])
    }

    @Test func onlyAppleSeesComesBeforeAppReviewAlone() {
        let items = AppInformationPageCards.items { _ in ready }
        #expect(items.filter { $0.groupTitle != nil }.map(\.id) == [.appReview])
        #expect(items.first { $0.id == .appReview }?.groupTitle == "Only Apple sees")
        #expect(AppInformationPage.allCases.filter(\.isSeenOnlyByApple) == [.appReview, .exportCompliance])
    }

    @Test func identifiersAreThePagesRawValues() {
        let items = AppInformationPageCards.items { _ in ready }
        #expect(items.compactMap(\.identifier) == AppInformationPageCards.order.map(\.rawValue))
        #expect(items.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test func eachCardSaysItsPagesStatusInItsColour() {
        let items = AppInformationPageCards.items { page in
            switch page {
            case .general: AppInformationPageStatus(isLoaded: true, suggested: 3, needsYou: 0)
            case .appCompliance: AppInformationPageStatus(isLoaded: true, suggested: 0, needsYou: 2)
            case .accessibility: AppInformationPageStatus(isLoaded: false, suggested: 0, needsYou: 0)
            default: ready
            }
        }
        let general = items.first { $0.id == .general }
        #expect(general?.status == "3 suggested")
        #expect(general?.tone == .ai)
        let compliance = items.first { $0.id == .appCompliance }
        #expect(compliance?.status == "2 need you")
        #expect(compliance?.tone == .warning)
        let accessibility = items.first { $0.id == .accessibility }
        #expect(accessibility?.isLoading == true)
        #expect(accessibility?.status == nil)
        let review = items.first { $0.id == .appReview }
        #expect(review?.status == "Ready")
        #expect(review?.tone == .ok)
    }
}
