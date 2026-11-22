//
//  StartingPricesTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// App Store Connect for one subscription's starting price: $9.99 in the
/// United States, equalized in `territories` other ones (`T001`, …, at
/// `e1`, …), some of them priced already. The `PATCH` that sets prices in
/// batches can be refused or fail at its `n`th time; writes take a moment
/// and the most in flight at once is kept.
final class StartingPricesTransport: PushTransport {
    private struct State {
        var sent: [PushRequest] = []
        var patches = 0
        var inFlight = 0
        var mostInFlight = 0
    }

    static let subscriptionID = "sub1"

    static let pricePoints = "/v1/subscriptions/sub1/pricePoints?filter%5Bterritory%5D=USA"
        + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"
    static let equalizations = "/v1/subscriptionPricePoints/p2/equalizations?include=territory"
        + "&fields%5BsubscriptionPricePoints%5D=customerPrice,territory&fields%5Bterritories%5D=currency&limit=200"
    static let prices = "/v1/subscriptions/sub1/prices?include=territory&fields%5BsubscriptionPrices%5D=territory"
        + "&fields%5Bterritories%5D=currency&limit=200"

    private let state = Mutex(State())
    private let territories: Int
    private let priced: [String]
    private let patchFailure: (any Error)?
    private let failingPatch: Int
    private let delay: Duration

    /// `patchFailure` is thrown by the `failingPatch`th `PATCH` (1-based).
    init(territories: Int = 174, priced: [String] = [], patchFailure: (any Error)? = nil, failingPatch: Int = 1, delay: Duration = .milliseconds(5)) {
        self.territories = territories
        self.priced = priced
        self.patchFailure = patchFailure
        self.failingPatch = failingPatch
        self.delay = delay
    }

    static func territory(_ index: Int) -> String {
        "T" + String(format: "%03d", index)
    }

    var sent: [PushRequest] { state.withLock { $0.sent } }
    var mostInFlight: Int { state.withLock { $0.mostInFlight } }
    var patches: [PushRequest] { sent.filter { $0.method == .patch } }
    var posts: [PushRequest] { sent.filter { $0.method == .post } }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        let patch = state.withLock { state in
            state.sent.append(request)
            state.inFlight += 1
            state.mostInFlight = max(state.mostInFlight, state.inFlight)
            if request.method == .patch { state.patches += 1 }
            return request.method == .patch ? state.patches : 0
        }
        try? await Task.sleep(for: delay)
        state.withLock { $0.inFlight -= 1 }
        if patch == failingPatch, let patchFailure { throw patchFailure }
        return AppStoreConnectResponse(data: Data(), rateLimit: nil)
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let body = switch path {
        case Self.pricePoints:
            #"{"data":[{"id":"p1","attributes":{"customerPrice":"8.99"}},{"id":"p2","attributes":{"customerPrice":"9.99"}}]}"#
        case Self.equalizations:
            #"{"data":[\#((1..<(territories + 1)).map { Self.resource("e\($0)", Self.territory($0)) }.joined(separator: ","))]}"#
        case Self.prices:
            #"{"data":[\#(priced.enumerated().map { Self.resource("price\($0.offset)", $0.element) }.joined(separator: ","))]}"#
        default:
            "{}"
        }
        return AppStoreConnectResponse(data: Data(body.utf8), rateLimit: nil)
    }

    private static func resource(_ id: String, _ territory: String) -> String {
        #"{"id":"\#(id)","relationships":{"territory":{"data":{"type":"territories","id":"\#(territory)"}}}}"#
    }
}
