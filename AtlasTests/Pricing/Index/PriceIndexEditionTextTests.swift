//
//  PriceIndexEditionTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("PriceIndexEditionText")
struct PriceIndexEditionTextTests {
    /// The bundled JSON's raw editions, by source key.
    private func rawEditions() throws -> [String: [String: Any]] {
        let url = try #require(Bundle.main.url(forResource: PriceIndexSnapshot.resourceName, withExtension: "json"))
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let sources = try #require(object["sources"] as? [String: [String: Any]])
        return sources.compactMapValues { $0["edition"] as? [String: Any] }
    }

    @Test func everyShownTextOfTheBundledJSONHasAnEntry() throws {
        let editions = try rawEditions()
        #expect(Set(editions.keys) == ["bigMac", "worldBank", "imf"])
        for (source, edition) in editions {
            for field in PriceIndexEditionText.Field.allCases {
                guard let value = edition[field.rawValue] as? String else { continue }
                let id = PriceIndexEditionText.id(source, field)
                #expect(PriceIndexEditionText.english(id: id) == value, "\(id)")
            }
        }
    }

    @Test func knownEnglishIsLocalizedAndStaysEnglishInEnglish() {
        #expect(PriceIndexEditionText.text("Big Mac Jan 26", id: "bigMac.badge") == "Big Mac Jan 26")
        #expect(PriceIndexEditionText.text("World Bank 2024", id: "worldBank.provenanceLabel") == "World Bank 2024")
    }

    @Test func aNewerSnapshotsTextShowsAsWritten() {
        #expect(PriceIndexEditionText.text("Big Mac Jul 26", id: "bigMac.badge") == "Big Mac Jul 26")
        #expect(PriceIndexEditionText.text("January 2026", id: "custom.label") == "January 2026")
    }

    @Test func idJoinsSourceAndField() {
        #expect(PriceIndexEditionText.id("imf", .newerEdition) == "imf.newerEdition")
    }

    @Test func bundledSnapshotKeepsItsEditionTexts() throws {
        let snapshot = try PriceIndexSnapshot.bundled()
        let bigMac = try #require(snapshot.index(.bigMac)?.edition)
        #expect(bigMac.label == "January 2026")
        #expect(bigMac.badge == "Big Mac Jan 26")
        #expect(bigMac.provenanceLabel == "Big Mac, Jan 2026")
        #expect(bigMac.newerEditionLabel == "July 2026 available")
        #expect(snapshot.index(.worldBank)?.edition.newerEdition == nil)
    }
}
