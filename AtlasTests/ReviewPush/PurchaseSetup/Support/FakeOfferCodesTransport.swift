//
//  FakeOfferCodesTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Keeps one offer code's custom codes and one-time code batches like App
/// Store Connect would: a `POST` adds one and answers with its ID, and the
/// offer code's lists return what it has now. A new offer code's `POST`
/// answers with `offerCodeID`. `madeButTimedOut` `POST`s
/// (in order) add their code and then time out, as when Apple made it after
/// Atlas stopped waiting; `failsBeforeMaking` ones time out without adding.
final class FakeOfferCodesTransport: PushTransport {
    struct Code: Sendable {
        var id: String
        var attributes: [String: String]
        var count: Int
    }

    private struct State {
        var customCodes: [Code] = []
        var batches: [Code] = []
        var posts: [PushRequest] = []
        var fetched: [String] = []
        var made = 0
    }

    let offerCodeID: String
    private let state: Mutex<State>
    private let madeButTimedOut: Mutex<Int>
    private let failsBeforeMaking: Mutex<Int>

    init(offerCodeID: String, batches: [Code] = [], madeButTimedOut: Int = 0, failsBeforeMaking: Int = 0) {
        self.offerCodeID = offerCodeID
        state = Mutex(State(batches: batches))
        self.madeButTimedOut = Mutex(madeButTimedOut)
        self.failsBeforeMaking = Mutex(failsBeforeMaking)
    }

    /// A batch App Store Connect has: its count, expiry and environment.
    static func batch(_ id: String, count: Int, expires: String, environment: String = "PRODUCTION") -> Code {
        Code(id: id, attributes: ["expirationDate": expires, "environment": environment], count: count)
    }

    var posts: [PushRequest] { state.withLock { $0.posts } }
    var customCodes: [Code] { state.withLock { $0.customCodes } }
    var batches: [Code] { state.withLock { $0.batches } }
    var fetched: [String] { state.withLock { $0.fetched } }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        state.withLock { $0.posts.append(request) }
        if request.path == SubscriptionOfferResource.offerCode.path {
            return AppStoreConnectResponse(data: Data(#"{"data":{"type":"subscriptionOfferCodes","id":"\#(offerCodeID)"}}"#.utf8), rateLimit: nil)
        }
        if failsBeforeMaking.withLock({ count in
            defer { count = max(0, count - 1) }
            return count > 0
        }) { throw URLError(.timedOut) }
        let attributes = (PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any] ?? [:]
        let made: (id: String, type: String) = state.withLock { state in
            state.made += 1
            let count = attributes["numberOfCodes"] as? Int ?? 0
            if request.path == NewCustomCode.path {
                let code = Code(id: "cc\(state.made)", attributes: ["customCode": attributes["customCode"] as? String ?? ""], count: count)
                state.customCodes.append(code)
                return (code.id, "subscriptionOfferCodeCustomCodes")
            }
            let batch = Self.batch(
                "ot\(state.made)", count: count, expires: attributes["expirationDate"] as? String ?? "",
                environment: attributes["environment"] as? String ?? "PRODUCTION"
            )
            state.batches.append(batch)
            return (batch.id, "subscriptionOfferCodeOneTimeUseCodes")
        }
        if madeButTimedOut.withLock({ count in
            defer { count = max(0, count - 1) }
            return count > 0
        }) { throw URLError(.timedOut) }
        return AppStoreConnectResponse(data: Data(#"{"data":{"type":"\#(made.type)","id":"\#(made.id)"}}"#.utf8), rateLimit: nil)
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let codes: [Code] = state.withLock { state in
            state.fetched.append(path)
            if path == ExistingCustomCode.listPath(offerCodeID: offerCodeID) { return state.customCodes }
            if path == ExistingOneTimeCodes.listPath(offerCodeID: offerCodeID) { return state.batches }
            return []
        }
        let items = codes.map { code in
            var attributes: [String: Any] = code.attributes
            attributes["numberOfCodes"] = code.count
            let json = (try? JSONSerialization.data(withJSONObject: ["id": code.id, "attributes": attributes])) ?? Data()
            return String(bytes: json, encoding: .utf8) ?? "{}"
        }
        return AppStoreConnectResponse(data: Data(#"{"data":[\#(items.joined(separator: ","))]}"#.utf8), rateLimit: nil)
    }
}
