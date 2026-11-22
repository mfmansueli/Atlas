//
//  PushController+Connection.swift
//  Atlas
//

import Foundation

/// “You’re offline” follows the Mac's real connection: a request that timed
/// out or couldn't reach Apple while the Mac is online isn't “offline” (the
/// section or the push row says what failed), and the banner leaves by
/// itself when the connection comes back.
extension PushController {
    /// Starts following the Mac's connection; the caller keeps `watcher`
    /// for as long as it should follow.
    func watchConnection(_ watcher: NetworkPathWatcher) {
        watcher.start { [weak self] isOnline in
            self?.connectionChanged(isOnline: isOnline)
        }
    }

    /// The Mac's connection changed (or was first known).
    func connectionChanged(isOnline: Bool) {
        self.isOnline = isOnline
        if isOnline, notice == .offline { dismissNotice() }
    }

    /// Whether an offline error should show the banner: only while the Mac
    /// has no network, or before its connection is known.
    var showsOfflineNotice: Bool {
        isOnline != true
    }
}
