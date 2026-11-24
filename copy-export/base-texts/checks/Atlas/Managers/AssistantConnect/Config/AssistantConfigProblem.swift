//
//  AssistantConfigProblem.swift
//  Atlas
//

import Foundation

/// Why Atlas couldn't add itself to an assistant's settings.
enum AssistantConfigProblem: LocalizedError, Equatable {
    /// The settings folder isn't there yet: the assistant was never opened.
    case folderMissing(ConnectableAssistant)
    /// The person closed the panel that lets Atlas write there.
    case notAllowed(ConnectableAssistant)
    /// They chose another folder than the assistant's.
    case wrongFolder(ConnectableAssistant, chosen: String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case let .folderMissing(assistant):
            String(localized: "\(assistant.title) hasn’t made its settings folder yet. Open it once, then try again.")
        case let .notAllowed(assistant):
            String(localized: "Atlas needs to be allowed into \(assistant.title)’s settings folder once, to add itself there.")
        case let .wrongFolder(assistant, chosen):
            String(localized: "“\(chosen)” isn’t \(assistant.title)’s settings folder. Choose the folder Atlas opens the panel in.")
        case let .writeFailed(message):
            message
        }
    }
}
