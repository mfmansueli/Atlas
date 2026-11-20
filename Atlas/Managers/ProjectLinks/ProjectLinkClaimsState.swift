//
//  ProjectLinkClaimsState.swift
//  Atlas
//

import Foundation

/// What Atlas could read of the links an app's project claims.
enum ProjectLinkClaimsState: Hashable, Sendable {
    /// Not read yet.
    case unknown
    /// The app has no project folder in Settings → AI Assistants.
    case noFolder
    /// The folder is there, but Atlas couldn't tell: no Xcode project, no
    /// app target, or no access. Says why.
    case unreadable(folder: String, reason: String)
    case read(folder: String, claims: ProjectLinkClaims)

    var claims: ProjectLinkClaims? {
        if case let .read(_, claims) = self { return claims }
        return nil
    }

    var folder: String? {
        switch self {
        case .unknown, .noFolder: nil
        case let .unreadable(folder, _), let .read(folder, _): folder
        }
    }
}
