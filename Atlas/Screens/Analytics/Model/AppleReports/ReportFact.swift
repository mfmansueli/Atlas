//
//  ReportFact.swift
//  Atlas
//

import Foundation

/// One day's numbers for one combination of a report's kept columns:
/// `values` follow the kind's `dimensions`, `counts` its `measures`.
/// Rows with the same values add up.
struct ReportFact: Hashable, Sendable, Codable {
    var day: AnalyticsDay
    var values: [String]
    var counts: [Int]

    private enum CodingKeys: String, CodingKey {
        case day = "d", values = "v", counts = "c"
    }

    /// Everything but the counts.
    struct Key: Hashable {
        var day: AnalyticsDay
        var values: [String]
    }

    var key: Key { Key(day: day, values: values) }

    /// Facts with the same day and values merged, in a stable order.
    static func merged(_ facts: [ReportFact]) -> [ReportFact] {
        var byKey: [Key: ReportFact] = [:]
        for fact in facts {
            if var known = byKey[fact.key] {
                for index in fact.counts.indices {
                    if known.counts.indices.contains(index) { known.counts[index] += fact.counts[index] } else { known.counts.append(fact.counts[index]) }
                }
                byKey[fact.key] = known
            } else {
                byKey[fact.key] = fact
            }
        }
        return byKey.values.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.values.lexicographicallyPrecedes(rhs.values)
        }
    }
}
