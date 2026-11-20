//
//  InAppEventReadAgain.swift
//  Atlas
//

import Foundation

/// The one more read of the events once dates just pushed are no longer
/// trusted (`InAppEventPushedDates`): once per push, when its two minutes
/// end, so the page and the Submit sheet show what App Store Connect kept.
@MainActor
final class InAppEventReadAgain {
    /// Waits that many seconds; tests skip it.
    var pause: (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    /// The read waiting, if any.
    private(set) var task: Task<Void, Never>?
    private var date: Date?

    /// Reads again a moment after `date`; nothing when `date` is nil or
    /// already waited for (a read in the same window doesn't ask again).
    func schedule(at date: Date?, now: Date, read: @escaping @MainActor () async -> Void) {
        guard let date, date != self.date else { return }
        self.date = date
        task?.cancel()
        let pause = pause
        task = Task { @MainActor in
            await pause(max(0, date.timeIntervalSince(now)) + 1)
            guard !Task.isCancelled else { return }
            await read()
        }
    }
}
