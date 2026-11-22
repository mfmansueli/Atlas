//
//  PageShotsStudio+RecaptureRequest.swift
//  Atlas
//

import Foundation

/// `request_page_recapture` accepted (or let open by itself): the page's
/// Capture Screens Again is turned on for the screens the assistant asked
/// for, without the person pressing Make Screenshots for This Page first.
/// A page without a run gets one at Plan, so its run, its upload link and
/// get_page_screenshots are there for the captures; the person makes the
/// set from it later.
extension PageShotsStudio {
    /// Turns on Capture Screens Again for `target`'s screens, making the
    /// page's run when it has none. Returns the run's key.
    @discardableResult
    func openRecapture(_ target: PageRecaptureTarget, reason: String?, app: StoreApp, source: PageShotsSource, now: Date = .now) -> PageShotsRun.Key {
        let key = PageShotsRun.Key(appID: app.id, pageName: target.pageName)
        if runs[key] == nil || runs[key]?.stage == .used {
            let languages = source.document.scope.orderedLocales(in: StoreLocaleCatalog.all.map(\.code))
            let primary = languages.first ?? source.primary
            let locales = [primary] + (target.locale == primary || !languages.contains(target.locale) ? [] : [target.locale])
            begin(PageShotsRun(
                id: UUID().uuidString.lowercased(), appID: app.id, pageID: target.pageID, pageName: target.pageName, note: "", stage: .plan,
                languages: languages, locales: locales, displays: source.displays, templateName: source.template?.name ?? "",
                startedAt: now, updatedAt: now
            ))
        }
        update(key) { run in
            if run.recapture == nil { run.recapture = PageShotsRecapture(uploadToken: AutopilotCenter.makeToken()) }
            run.recapture?.requested = target
            run.recapture?.requestReason = reason
            run.recapture?.problem = nil
        }
        return key
    }

    /// Before the assistant captures `target`'s screens: its device's
    /// simulator is made when only the simulator is missing. A make that
    /// failed is the page's problem, with what `create-simulator` said; a
    /// runtime to download stays the assistant's to report.
    func makeSimulator(for target: PageRecaptureTarget, key: PageShotsRun.Key, simulators: MacSimulators?) async {
        guard let simulators, case let .failed(reason) = await simulators.maker.makeIfMissing(target.displayType) else { return }
        update(key) { run in
            run.recapture?.problem = String(localized: "Atlas couldn’t make the \(target.displayType.deviceName) simulator: \(reason)")
        }
    }
}
