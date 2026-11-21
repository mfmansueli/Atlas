//
//  ProductPageReviewWatch.swift
//  Atlas
//

import Foundation

/// Follows custom product pages' versions with App Review from one read to
/// the next: a version waiting or in review is remembered with its state,
/// and the next read says where it went. Only In Review, Approved and
/// Rejected are told; a version that's gone or was taken back is dropped.
enum ProductPageReviewWatch {
    /// The versions to follow after `pages` was read, and what moved since
    /// `followed` (version ID → state seen last).
    static func follow(
        _ pages: [ProductPage], after followed: [String: ProductPageState]
    ) -> (moves: [ProductPageReviewMove], followed: [String: ProductPageState]) {
        var moves: [ProductPageReviewMove] = []
        var next: [String: ProductPageState] = [:]
        for page in pages where !page.isDraft {
            for version in page.versions where !version.id.isEmpty {
                let seen = followed[version.id]
                if version.state.isLocked { next[version.id] = version.state }
                guard let seen, seen != version.state else { continue }
                let move = ProductPageReviewMove(pageID: page.id, pageName: page.name, state: version.state)
                if move.isTold { moves.append(move) }
            }
        }
        return (moves, next)
    }
}
