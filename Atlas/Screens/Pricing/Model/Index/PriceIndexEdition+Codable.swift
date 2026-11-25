//
//  PriceIndexEdition+Codable.swift
//  Atlas
//

import Foundation

// Dates are `yyyy-MM-dd` strings in PriceIndexSnapshot.json.
extension PriceIndexEdition: Codable {
    private enum CodingKeys: String, CodingKey {
        case label, badge, provenanceLabel, date, newerEdition, dataYear, url
        case fetchDate = "fetched"
    }

    static func parseDay(_ text: String) throws -> Date {
        try Date(text, strategy: Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }

    static func dayString(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            label: container.decode(String.self, forKey: .label),
            badge: container.decode(String.self, forKey: .badge),
            provenanceLabel: container.decode(String.self, forKey: .provenanceLabel),
            date: Self.parseDay(container.decode(String.self, forKey: .date)),
            newerEdition: container.decodeIfPresent(String.self, forKey: .newerEdition),
            dataYear: container.decodeIfPresent(Int.self, forKey: .dataYear),
            fetchDate: container.decodeIfPresent(String.self, forKey: .fetchDate).map(Self.parseDay),
            url: container.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(badge, forKey: .badge)
        try container.encode(provenanceLabel, forKey: .provenanceLabel)
        try container.encode(Self.dayString(date), forKey: .date)
        try container.encodeIfPresent(newerEdition, forKey: .newerEdition)
        try container.encodeIfPresent(dataYear, forKey: .dataYear)
        try container.encodeIfPresent(fetchDate.map(Self.dayString), forKey: .fetchDate)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
    }
}
