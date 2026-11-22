//
//  AppPriceAvailabilityWrite.swift
//  Atlas
//

import Foundation

/// A queued `POST` of the app's price schedule or first availability
/// (`AppPriceAvailabilityRequests`), sent as it is. When Apple refuses it,
/// the push row says what usually causes that, with Apple's own words,
/// since Atlas can't know beforehand: whether the Paid Applications
/// agreement is active, or an availability was set up in App Store Connect
/// meanwhile (`AppPriceAvailabilityRefusal`).
struct AppPriceAvailabilityWrite: Sendable {
    enum Kind: Hashable, Sendable {
        case price
        case availability
    }

    let kind: Kind
    let request: PushRequest

    init?(_ request: PushRequest) {
        guard request.method == .post else { return nil }
        switch request.path {
        case AppPriceAvailabilityRequests.priceSchedulesPath: kind = .price
        case AppPriceAvailabilityRequests.availabilitiesPath: kind = .availability
        default: return nil
        }
        self.request = request
    }

    func send(via transport: any PushTransport) async throws -> AppStoreConnectResponse {
        do {
            return try await transport.send(request)
        } catch let error as AppStoreConnectError {
            throw AppPriceAvailabilityRefusal(kind: kind, error: error) ?? error
        }
    }
}
