//
//  StarHistogram.swift
//  Atlas
//

import Foundation

/// How many written reviews gave each number of stars.
struct StarHistogram: Hashable, Sendable {
    /// Index 0 is 1 star, index 4 is 5 stars.
    private(set) var counts = [0, 0, 0, 0, 0]

    init(_ reviews: [AppReview] = []) {
        for review in reviews where (1...5).contains(review.rating) {
            counts[review.rating - 1] += 1
        }
    }

    var total: Int { counts.reduce(0, +) }

    func count(stars: Int) -> Int {
        (1...5).contains(stars) ? counts[stars - 1] : 0
    }

    /// 0 to 1; 0 without reviews.
    func share(stars: Int) -> Double {
        total > 0 ? Double(count(stars: stars)) / Double(total) : 0
    }

    /// The written reviews' own average; nil without any.
    var average: Double? {
        guard total > 0 else { return nil }
        let sum = counts.enumerated().reduce(0) { $0 + ($1.offset + 1) * $1.element }
        return Double(sum) / Double(total)
    }
}
