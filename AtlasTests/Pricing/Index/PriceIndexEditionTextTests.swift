//
//  PriceIndexEditionTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("PriceIndexEditionText")
struct PriceIndexEditionTextTests {
    /// A bundled JSON's raw editions, by source key.
    private func rawEditions(_ resource: String = PriceIndexSnapshot.sampleResourceName) throws -> [String: [String: Any]] {
        let url = try #require(Bundle.main.url(forResource: resource, withExtension: "json"))
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let sources = try #require(object["sources"] as? [String: [String: Any]])
        return sources.compactMapValues { $0["edition"] as? [String: Any] }
    }

    @Test func everyShownTextOfTheSampleJSONHasAnEntry() throws {
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

    /// Each text the script wrote matches the pattern Atlas translates, so a
    /// new edition needs no new strings. Fails when the script's wording and
    /// `PriceIndexEditionText.generated` drift apart.
    @Test func everyShownTextOfThePublishedJSONFollowsItsPattern() throws {
        let editions = try rawEditions(PriceIndexSnapshot.resourceName)
        #expect(Set(editions.keys) == ["bigMac", "worldBank", "imf"])
        for (source, raw) in editions {
            let edition = try JSONDecoder().decode(PriceIndexEdition.self, from: JSONSerialization.data(withJSONObject: raw))
            let built = PriceIndexEditionText.generated(for: edition, source: source)
            for field in [PriceIndexEditionText.Field.label, .badge, .provenanceLabel] {
                #expect(built[field]?.english == raw[field.rawValue] as? String, "\(source).\(field.rawValue)")
            }
        }
    }

    @Test func publishedEditionTextsComeFromTheDataYearAndDate() {
        let edition = PriceIndexEdition(
            label: "2025 data, published 2026", badge: "WB 2025", provenanceLabel: "World Bank 2025",
            date: PricingSampleData.date("2026-11-11"), newerEdition: nil, dataYear: 2025
        )
        let worldBank = PriceIndexEditionText.generated(for: edition, source: "worldBank")
        #expect(worldBank[.label]?.english == "2025 data, published 2026")
        #expect(worldBank[.badge]?.english == "WB 2025")
        #expect(worldBank[.provenanceLabel]?.english == "World Bank 2025")
        var imf = edition
        imf.date = PricingSampleData.date("2026-10-08")
        let imfTexts = PriceIndexEditionText.generated(for: imf, source: "imf")
        #expect(imfTexts[.label]?.english == "October 2026 WEO")
        #expect(imfTexts[.badge]?.english == "IMF Oct 26")
        #expect(imfTexts[.provenanceLabel]?.english == "IMF, Oct 2026")
        var bigMac = edition
        bigMac.date = PricingSampleData.date("2026-07-01")
        bigMac.dataYear = 2026
        let bigMacTexts = PriceIndexEditionText.generated(for: bigMac, source: "bigMac")
        #expect(bigMacTexts[.label]?.english == "July 2026")
        #expect(bigMacTexts[.badge]?.english == "Big Mac Jul 26")
        #expect(bigMacTexts[.provenanceLabel]?.english == "Big Mac, Jul 2026")
    }

    @Test func editionsWithoutADataYearHaveNoPattern() {
        let edition = PriceIndexEdition(label: "L", badge: "B", provenanceLabel: "P", date: PricingSampleData.date("2026-01-01"), newerEdition: nil)
        #expect(PriceIndexEditionText.generated(for: edition, source: "worldBank").isEmpty)
    }

    @Test func sampleSnapshotKeepsItsEditionTexts() throws {
        let snapshot = try PriceIndexSnapshot.sample()
        let bigMac = try #require(snapshot.index(.bigMac)?.edition)
        #expect(bigMac.label == "January 2026")
        #expect(bigMac.badge == "Big Mac Jan 26")
        #expect(bigMac.provenanceLabel == "Big Mac, Jan 2026")
        #expect(bigMac.newerEditionLabel == "July 2026 available")
        #expect(snapshot.index(.worldBank)?.edition.newerEdition == nil)
    }
}
