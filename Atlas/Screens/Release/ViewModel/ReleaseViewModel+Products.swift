//
//  ReleaseViewModel+Products.swift
//  Atlas
//

import Foundation

// The Submit sheet's subscriptions and in-app purchases: every one Ready to
// Submit can go to App Review with the version, and starts ticked (a first
// one only reaches App Review with a version).
extension ReleaseViewModel {
    /// The products Ready to Submit, as App Store Connect has them.
    var offeredProducts: [SubmissionProduct] {
        status?.productsToSubmit ?? []
    }

    /// The ticked ones, in the list's order.
    var tickedProducts: [SubmissionProduct] {
        offeredProducts.filter { options.productIDs.contains($0.id) }
    }

    func setProduct(_ id: SubmissionProduct.ID, goesWithVersion: Bool) {
        if goesWithVersion {
            options.productIDs.insert(id)
        } else {
            options.productIDs.remove(id)
        }
    }

    /// The ticks after the version is read again: the person's stay for
    /// products still offered, and one that just became Ready to Submit
    /// starts ticked.
    static func keptProductIDs(_ ticked: Set<SubmissionProduct.ID>, before: ReleaseStatus, now: ReleaseStatus) -> Set<SubmissionProduct.ID> {
        let known = Set(before.productsToSubmit.map(\.id))
        let offered = Set(now.productsToSubmit.map(\.id))
        return ticked.intersection(offered).union(offered.subtracting(known))
    }
}
