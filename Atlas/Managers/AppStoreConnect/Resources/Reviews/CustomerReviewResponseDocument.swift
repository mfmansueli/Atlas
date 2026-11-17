//
//  CustomerReviewResponseDocument.swift
//  Atlas
//

import Foundation

/// The answer to creating a reply: `{"data": {…}}`.
struct CustomerReviewResponseDocument: Decodable, Sendable {
    var data: AppStoreConnectResource<CustomerReviewResponseAttributes>
}
