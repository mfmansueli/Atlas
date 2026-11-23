//
//  ProductPageTreatmentAttributes.swift
//  Atlas
//

import Foundation

/// An `appStoreVersionExperimentTreatments` resource's attributes.
struct ProductPageTreatmentAttributes: Decodable, Sendable {
    var name: String?
    /// ISO 8601; set once it was applied to the original page.
    var promotedDate: String?

    private enum CodingKeys: String, CodingKey {
        case name, promotedDate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        promotedDate = try? container.decodeIfPresent(String.self, forKey: .promotedDate)
    }
}
