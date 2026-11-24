//
//  NominationPlaceholder.swift
//  Atlas
//

import Foundation

/// A draft on this Mac named in a request before App Store Connect gave it
/// an ID: its Submit row is `PATCH /v1/nominations/{queuedNomination:…}`
/// and waits for its Create row (`PendingChange.dependsOn`). The push fills
/// it in with the ID the create got, in this push; or, when an earlier
/// push created it, with the app's draft of that name.
///
/// The token is `{queuedNomination:<appID>:<localID>:<name, base64url>}`.
struct NominationPlaceholder: Hashable, Sendable {
    var appID: StoreApp.ID
    var localID: String
    var name: String

    static let opening = "{queuedNomination:"

    var token: String {
        let encoded = Data(name.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(Self.opening)\(appID):\(localID):\(encoded)}"
    }

    init(appID: StoreApp.ID, localID: String, name: String) {
        self.appID = appID
        self.localID = localID
        self.name = name
    }

    /// The first placeholder in `request`'s path or body; nil without one.
    init?(in request: PushRequest) {
        for text in [request.path, request.bodyText ?? ""] {
            guard let start = text.range(of: Self.opening), let end = text[start.upperBound...].firstIndex(of: "}") else { continue }
            let parts = text[start.upperBound..<end].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty, let name = Self.decoded(parts[2]) else { return nil }
            self.init(appID: parts[0], localID: parts[1], name: name)
            return
        }
        return nil
    }

    private static func decoded(_ text: String) -> String? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while !base64.count.isMultiple(of: 4) { base64 += "=" }
        return Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The draft wasn't created, in this push or an earlier one: its submit
    /// waits in Review & Push and goes once it is.
    struct NotCreated: LocalizedError, Equatable {
        var name: String

        var errorDescription: String? {
            String(localized: "“\(name)” isn’t in App Store Connect yet. Push its draft first, then the submit.", comment: "kind:error")
        }
    }
}
