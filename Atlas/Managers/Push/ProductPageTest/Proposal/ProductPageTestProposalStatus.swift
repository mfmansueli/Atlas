//
//  ProductPageTestProposalStatus.swift
//  Atlas
//

import Foundation

/// Where a proposed test stands. Only the person moves it past `pending`,
/// except `withdrawn`, which the assistant that sent it may do.
enum ProductPageTestProposalStatus: String, Codable, Hashable, Sendable {
    /// Waits in Review & Push.
    case pending
    /// The person created the test from it (or exported both variants
    /// when the API couldn't): `outcome` says which.
    case made
    case dismissed
    /// Taken back by the assistant that sent it.
    case withdrawn
}
