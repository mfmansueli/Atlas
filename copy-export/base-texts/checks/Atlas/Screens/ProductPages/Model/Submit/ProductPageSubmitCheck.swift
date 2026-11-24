//
//  ProductPageSubmitCheck.swift
//  Atlas
//

import Foundation

/// One line of Submit for Review's "What goes to Apple": what goes, and
/// whether Atlas found something App Review may stop.
struct ProductPageSubmitCheck: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    /// False shows it as a warning.
    var isFine = true
}
