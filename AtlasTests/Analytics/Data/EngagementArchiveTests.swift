//
//  EngagementArchiveTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the facts kept on this Mac")
struct EngagementArchiveTests {
    private let day = AnalyticsDay(number: 20000)

    private func fact(_ day: AnalyticsDay, impressions: Int = 0, views: Int = 0, downloads: Int = 0) -> EngagementFact {
        var fact = EngagementFact(day: day, territory: "US", source: "App Store Search", device: "iPhone")
        fact.impressions = impressions
        fact.pageViews = views
        fact.downloads = downloads
        return fact
    }

    private func batch(_ id: String, _ kind: EngagementReportKind, processed: Int, _ facts: [EngagementFact], detailed: Bool = false) -> EngagementBatch {
        EngagementBatch(instanceID: id, kind: kind, isDetailed: detailed, processing: day.adding(processed), facts: facts)
    }

    @Test func theTwoReportsMeetInOneFact() {
        var archive = EngagementArchive()
        archive.apply([
            batch("e1", .engagement, processed: 1, [fact(day, impressions: 100, views: 8)]),
            batch("d1", .downloads, processed: 1, [fact(day, downloads: 3)]),
        ])
        #expect(archive.facts.count == 1)
        #expect(archive.facts[0].impressions == 100)
        #expect(archive.facts[0].pageViews == 8)
        #expect(archive.facts[0].downloads == 3)
        #expect(archive.instanceIDs == ["e1", "d1"])
        #expect(archive.lastDay == day)
    }

    @Test func aLaterFileReplacesADaysNumbersInsteadOfAddingToThem() {
        var archive = EngagementArchive()
        archive.apply([batch("e1", .engagement, processed: 1, [fact(day, impressions: 100, views: 8)])])
        archive.apply([batch("d1", .downloads, processed: 1, [fact(day, downloads: 3)])])
        // Apple reprocessed the day: more impressions, and downloads stay.
        archive.apply([batch("e2", .engagement, processed: 3, [fact(day, impressions: 130, views: 9)])])
        #expect(archive.facts.count == 1)
        #expect(archive.facts[0].impressions == 130)
        #expect(archive.facts[0].pageViews == 9)
        #expect(archive.facts[0].downloads == 3)
        // An older file arriving late changes nothing.
        archive.apply([batch("e0", .engagement, processed: 0, [fact(day, impressions: 1, views: 1)])])
        #expect(archive.facts[0].impressions == 130)
    }

    @Test func detailedFilesOnlyFeedTheProductPages() {
        var archive = EngagementArchive()
        var page = fact(day, impressions: 50, views: 5)
        page.page = "Prompts"
        archive.apply([batch("x", .engagement, processed: 1, [page], detailed: true)])
        #expect(archive.facts.isEmpty)
        #expect(archive.pageFacts.count == 1)
        #expect(archive.pageFacts[0].page == "Prompts")
        #expect(archive.pageFacts[0].territory.isEmpty)
    }

    @Test func daysOlderThanTheWindowAreDropped() {
        var archive = EngagementArchive()
        archive.apply([batch("old", .engagement, processed: 1, [fact(day.adding(-EngagementArchive.keptDays - 5), impressions: 9)])])
        archive.apply([batch("new", .engagement, processed: 2, [fact(day, impressions: 10)])])
        #expect(archive.facts.map(\.day) == [day])
    }

    @Test func theArchiveSurvivesAFile() throws {
        var archive = EngagementArchive()
        archive.apply([batch("e1", .engagement, processed: 1, [fact(day, impressions: 100, views: 8)])])
        let data = try JSONEncoder().encode(archive)
        #expect(try JSONDecoder().decode(EngagementArchive.self, from: data) == archive)
    }
}
