//
//  AtlasCodeIdentity.swift
//  Atlas
//

import Foundation
import Security

/// Who Atlas is signed as: the running process, and the app on disk now.
///
/// macOS runs a script from `~/Library/Application Scripts/<ID>/` for an app
/// (`NSUserUnixTask`) after reading the signature of the app's file on disk,
/// not of the process asking. When that file is replaced while Atlas is open
/// by a build signed as something else (a `CODE_SIGNING_ALLOWED=NO` build is
/// signed as "Atlas", not `com.lima.atlas`), every run of the helper fails
/// with "The file “Start Claude Code.zsh” couldn’t be opened because you
/// don’t have permission to view it." (NSFileReadNoPermissionError, "Script
/// file is not in the application scripts folder."), whatever the helper is.
/// Saving the helper again doesn't help; opening Atlas again does.
struct AtlasCodeIdentity: Hashable, Sendable {
    /// The running process's signing identifier, e.g. `com.lima.atlas`.
    var running: String?
    /// The signing identifier of the app on disk now.
    var onDisk: String?

    /// The app on disk is signed as someone else than the running one.
    /// Unknown on either side counts as the same, so a check that couldn't
    /// read a signature never blocks a run.
    var isReplaced: Bool {
        guard let running, let onDisk else { return false }
        return running != onDisk
    }

    /// Reads both now.
    static func current() -> AtlasCodeIdentity {
        AtlasCodeIdentity(running: runningIdentifier(), onDisk: diskIdentifier(of: Bundle.main.bundleURL))
    }

    /// What the kernel holds for this process, which a rebuild doesn't
    /// change.
    private static func runningIdentifier() -> String? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        return SecTaskCopySigningIdentifier(task, nil) as String?
    }

    private static func diskIdentifier(of bundle: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, [], &information) == errSecSuccess,
              let values = information as? [String: Any] else { return nil }
        return values[kSecCodeInfoIdentifier as String] as? String
    }
}
