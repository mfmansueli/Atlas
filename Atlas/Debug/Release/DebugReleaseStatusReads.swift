//
//  DebugReleaseStatusReads.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Counts a scene's reads of the version's status, so a scene can answer
/// the first at once and hold the ones after it (the Submit sheet's).
@MainActor
final class DebugReleaseStatusReads {
    private var count = 0

    /// This read's number, from 1.
    func next() -> Int {
        count += 1
        return count
    }
}
#endif
