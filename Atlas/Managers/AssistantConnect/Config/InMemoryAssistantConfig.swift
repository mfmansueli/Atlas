//
//  InMemoryAssistantConfig.swift
//  Atlas
//

import Foundation

/// Settings files kept in memory, for DEBUG scenes and tests: the
/// person's real Claude for Mac and Cursor are never touched.
@MainActor
final class InMemoryAssistantConfig: AssistantConfigWriting {
    /// Each assistant's file, as written.
    private(set) var files: [ConnectableAssistant: Data] = [:]
    /// Thrown by the next `addAtlas`, as if the person refused the panel.
    var problem: AssistantConfigProblem?

    init(files: [ConnectableAssistant: Data] = [:]) {
        self.files = files
    }

    func addAtlas(to assistant: ConnectableAssistant, token: String, bridgePath: String) throws {
        if let problem { throw problem }
        let entry = AssistantConfigFile.entry(token: token, bridgePath: bridgePath)
        files[assistant] = try AssistantConfigFile.adding(entry, to: files[assistant], fileName: assistant.configFileName ?? "")
    }

    func removeAtlas(from assistant: ConnectableAssistant) {
        guard let data = try? AssistantConfigFile.removing(from: files[assistant], fileName: assistant.configFileName ?? "") else { return }
        files[assistant] = data
    }

    /// The token Atlas's entry carries now.
    func token(of assistant: ConnectableAssistant) -> String? {
        AssistantConfigFile.token(in: files[assistant])
    }
}
