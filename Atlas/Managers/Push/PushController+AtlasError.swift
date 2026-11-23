//
//  PushController+AtlasError.swift
//  Atlas
//

import Foundation

extension PushController {
    /// An error Atlas itself throws (a refusal, a page already made), whose
    /// description already says what happened and what to do. Any other
    /// error (the system's, a framework's) goes through `AppleErrorCopy`,
    /// so its own text is only ever shown as Details.
    nonisolated static func isAtlasError(_ error: any Error) -> Bool {
        String(reflecting: type(of: error)).hasPrefix("Atlas.")
    }

    /// A row's message for an error that isn't Apple's API refusing it:
    /// Atlas's own errors as they are, any other in Atlas's words with its
    /// own text after "Details:".
    static func failureText(_ error: any Error) -> String {
        if isAtlasError(error) { return error.localizedDescription }
        return AppleErrorCopy(String(localized: "The change wasn’t sent.", comment: "kind:error"), error: error).text
    }
}
