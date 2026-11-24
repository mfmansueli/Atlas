//
//  NominationSheet.swift
//  Atlas
//

import Foundation

/// The confirmation open on a nomination: Submit… or Archive…. Both add a
/// row to Review & Push; nothing is sent until the person pushes.
enum NominationSheet: Identifiable, Hashable, Sendable {
    case submit(String)
    case archive(String)

    var id: String {
        switch self {
        case let .submit(id): "submit.\(id)"
        case let .archive(id): "archive.\(id)"
        }
    }

    var nominationID: String {
        switch self {
        case let .submit(id), let .archive(id): id
        }
    }
}
