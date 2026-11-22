//
//  NewSubscriptionField.swift
//  Atlas
//

import Foundation

/// A field of Create Subscription or Create In-App Purchase, with App
/// Store Connect's limit. An in-app purchase's display texts are
/// `purchaseName` and `purchaseDescription`, whose limits differ.
enum NewSubscriptionField: String, CaseIterable, Hashable, Sendable {
    case groupReferenceName
    case groupDisplayName
    case referenceName
    case productID
    case displayName
    case description
    case purchaseName
    case purchaseDescription
    case price
    case reviewNote

    var title: String {
        switch self {
        case .groupReferenceName: String(localized: "Group reference name")
        case .groupDisplayName: String(localized: "Group display name")
        case .referenceName: String(localized: "Reference name")
        case .productID: String(localized: "Product ID")
        case .displayName, .purchaseName: String(localized: "Display name")
        case .description, .purchaseDescription: String(localized: "Description")
        case .price: String(localized: "Price")
        case .reviewNote: String(localized: "Review notes")
        }
    }

    /// The In-App Texts field a display text becomes, for App Review's
    /// rules; nil for what customers never see.
    var inAppTextField: InAppTextField? {
        switch self {
        case .groupDisplayName: .subscriptionGroupName
        case .displayName: .subscriptionName
        case .description: .subscriptionDescription
        case .purchaseName: .purchaseName
        case .purchaseDescription: .purchaseDescription
        case .groupReferenceName, .referenceName, .productID, .price, .reviewNote: nil
        }
    }

    /// The display texts use In-App Texts' limits; reference names and
    /// product IDs App Store Connect's.
    var limit: Int? {
        switch self {
        case .groupReferenceName, .referenceName: 64
        case .productID: 100
        case .groupDisplayName: InAppTextField.subscriptionGroupName.limit.maximum
        case .displayName: InAppTextField.subscriptionName.limit.maximum
        case .description: InAppTextField.subscriptionDescription.limit.maximum
        case .purchaseName: InAppTextField.purchaseName.limit.maximum
        case .purchaseDescription: InAppTextField.purchaseDescription.limit.maximum
        case .reviewNote: 4000
        case .price: nil
        }
    }
}
