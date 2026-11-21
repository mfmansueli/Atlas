//
//  PageShotsUpload.swift
//  Atlas
//

import Foundation

/// A PNG that arrived at a page run's upload link; report_page_capture
/// names it by `id`.
struct PageShotsUpload: Hashable, Sendable {
    var id: String
    var runID: String
    var file: CaptureFile
}
