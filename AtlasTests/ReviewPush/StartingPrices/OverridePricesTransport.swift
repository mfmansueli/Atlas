//
//  OverridePricesTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// `StartingPricesTransport` with Apple's own price points in `T001`
/// (4.49 and 4.99), for a new subscription's recommended price there;
/// remembers every path read.
final class OverridePricesTransport: PushTransport {
    let base: StartingPricesTransport
    private let reads = Mutex<[String]>([])

    static let pointsPath = "/v1/subscriptions/sub1/pricePoints?filter%5Bterritory%5D=T001"
        + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"

    init(territories: Int = 3) {
        base = StartingPricesTransport(territories: territories)
    }

    var fetched: [String] { reads.withLock { $0 } }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        try await base.send(request)
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        reads.withLock { $0.append(path) }
        guard path == Self.pointsPath else { return try await base.fetch(path) }
        let body = #"{"data":[{"id":"t1a","attributes":{"customerPrice":"4.49"}},{"id":"t1b","attributes":{"customerPrice":"4.99"}}]}"#
        return AppStoreConnectResponse(data: Data(body.utf8), rateLimit: nil)
    }
}
