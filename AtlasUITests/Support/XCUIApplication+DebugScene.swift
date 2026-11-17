//
//  XCUIApplication+DebugScene.swift
//  AtlasUITests
//

import XCTest

extension XCUIApplication {
    /// Launches Atlas on a DEBUG scene. Saved window state is
    /// ignored: when an earlier run left the main window closed, macOS would
    /// otherwise restore no window at all.
    func launch(debugScene scene: String) {
        launchArguments = ["-AtlasDebugScene", scene, "-ApplePersistenceIgnoreState", "YES"]
        launch()
    }
}
