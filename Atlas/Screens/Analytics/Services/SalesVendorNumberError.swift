//
//  SalesVendorNumberError.swift
//  Atlas
//

import Foundation

/// Apple refused the vendor number for Sales and Trends itself, not only
/// for the subscription reports (which refuse a vendor with nobody
/// subscribed yet with the same words).
struct SalesVendorNumberError: LocalizedError, Equatable {
    let vendorNumber: String

    var errorDescription: String? {
        String(
            localized: "Apple doesn’t know vendor number \(vendorNumber). Copy it again from Payments and Financial Reports.",
            comment: "kind:error"
        )
    }
}
