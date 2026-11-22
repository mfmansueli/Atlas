//
//  ClaudeCodeLauncher+ReplacedAtlas.swift
//  Atlas
//

import Foundation

/// A build written over the running Atlas: macOS then refuses every helper
/// call with "you don't have permission to view it" (`AtlasCodeIdentity`),
/// so the launcher says to open Atlas again instead.
extension ClaudeCodeLauncher {
    /// What the Atlas on disk is signed as when it isn't this one, nil
    /// when it is.
    func replacedAtlas() -> String? {
        let identity = codeIdentity()
        return identity.isReplaced ? identity.onDisk : nil
    }

    /// A run that ended before it started, with why, for the button that
    /// asked to show.
    func failedRun(
        _ purpose: ClaudeCodeRunPurpose,
        appID: StoreApp.ID,
        appName: String,
        prompt: String,
        failure: ClaudeCodeRunFailure
    ) -> ClaudeCodeRun.ID {
        let run = ClaudeCodeRun(
            id: UUID(),
            appID: appID,
            appName: appName,
            purpose: purpose,
            prompt: prompt,
            workingDirectory: projectFolder(for: appID) ?? "",
            startedAt: now()
        )
        append(run)
        end(run.id, as: .failed(failure))
        return run.id
    }
}
