//
//  NetworkPathWatcher.swift
//  Atlas
//

import Foundation
import Network

/// Tells whether this Mac has a network path, now and each time it changes,
/// so “You’re offline” shows only while it really is and leaves by itself
/// when the connection comes back.
final class NetworkPathWatcher: Sendable {
    private let monitor = NWPathMonitor()

    /// Starts watching; `onChange` gets the first answer at once, then every
    /// change, on the main actor.
    func start(onChange: @escaping @MainActor @Sendable (_ isOnline: Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in onChange(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "com.lima.atlas.network-path"))
    }

    deinit {
        monitor.cancel()
    }
}
