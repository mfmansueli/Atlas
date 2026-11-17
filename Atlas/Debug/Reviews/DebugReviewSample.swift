//
//  DebugReviewSample.swift
//  Atlas
//

#if DEBUG
import Foundation

/// One of the sample reviews written out in full, as on the design's
/// board: the review, what it means in English, and the reply suggested
/// for it (or already on the App Store).
struct DebugReviewSample {
    var id: String
    var territory: String
    var language: String
    var rating: Int
    var title: String
    var body: String
    var titleEN = ""
    var bodyEN = ""
    /// The day of November 2026 it was written.
    var day: Int
    var reply: String
    var replyEN = ""
    /// The reply is on the App Store already (since Nov 10).
    var isReplied = false
}
#endif
