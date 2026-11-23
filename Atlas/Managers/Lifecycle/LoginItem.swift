//
//  LoginItem.swift
//  Atlas
//

import Foundation
import Observation
import ServiceManagement

/// Settings → General → "Open Atlas at login", through
/// `SMAppService.mainApp`. macOS keeps the truth (the person can remove
/// the item in System Settings), so the toggle reads the service's status
/// each time. DEBUG scenes and tests use `inMemory`, never the real item.
@MainActor
@Observable
final class LoginItem {
    /// Whether macOS opens Atlas at login.
    private(set) var isEnabled: Bool
    /// Why the last change didn't take, e.g. macOS asking for approval in
    /// System Settings → General → Login Items.
    private(set) var problem: String?

    private let service: SMAppService?

    /// The real login item.
    init() {
        service = .mainApp
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private init(isEnabled: Bool) {
        service = nil
        self.isEnabled = isEnabled
    }

    /// A pretend login item, for DEBUG scenes and tests.
    static func inMemory(isEnabled: Bool = false) -> LoginItem {
        LoginItem(isEnabled: isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        problem = nil
        guard let service else {
            isEnabled = enabled
            return
        }
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            problem = AppleErrorCopy(String(localized: "Atlas couldn’t change its login item.", comment: "kind:error"), error: error).text
        }
        refresh()
        if enabled, service.status == .requiresApproval {
            problem = String(localized: "Allow Atlas in System Settings → General → Login Items.")
        }
    }

    /// Reads the status again, after the person may have changed it in
    /// System Settings.
    func refresh() {
        guard let service else { return }
        isEnabled = service.status == .enabled
    }
}
