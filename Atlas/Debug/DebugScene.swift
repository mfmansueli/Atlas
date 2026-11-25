//
//  DebugScene.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: launching with `-AtlasDebugScene <id>` opens one
/// screen straight away with canned data and no App Store Connect, so UI
/// tests and screenshots can reach every state. Never compiled into Release
/// builds. The ids are listed in `DebugSceneView`.
enum DebugScene {
    static let launchArgument = "-AtlasDebugScene"

    /// The requested scene id, e.g. `connect`, or nil for a normal launch.
    static var requestedID: String? {
        requestedID(in: ProcessInfo.processInfo.arguments)
    }

    static func requestedID(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: launchArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return DesignSceneAliases.resolve(arguments[index + 1])
    }
}
#endif
