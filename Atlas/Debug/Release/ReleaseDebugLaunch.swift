//
//  ReleaseDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a release DEBUG scene does once the version's status is read:
/// open the Submit sheet, with the choices the design's board shows.
struct ReleaseDebugLaunch {
    /// Taken by the main window when the selected app's status has loaded.
    @MainActor static var pending: ReleaseDebugLaunch?

    var opensSubmit = false
    /// The encryption question, answered in Export Compliance.
    var encryption: EncryptionAnswer?
    var timing: ReleaseTiming.Kind?

    /// Once the selected app's version is read: the scene's choices, and
    /// its Submit sheet.
    @MainActor
    static func applyPending(to model: ReleaseViewModel, navigator: WorkspaceNavigator) {
        guard let launch = pending, model.status != nil else { return }
        pending = nil
        launch.apply(to: model)
        if launch.opensSubmit { navigator.isSubmitPresented = true }
    }

    @MainActor
    func apply(to model: ReleaseViewModel) {
        model.now = { DebugReleaseData.today }
        if let timing { model.options.timing = timing }
    }
}
#endif
