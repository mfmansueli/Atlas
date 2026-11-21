//
//  PageShotsMCPRun.swift
//  Atlas
//

import Foundation

/// The page screenshot run a tool call is about: found by the page's name
/// or ID, with the app's Screenshots document to make it from.
@MainActor
struct PageShotsMCPRun {
    let app: StoreApp
    let run: PageShotsRun
    let source: PageShotsSource

    static func find(
        _ arguments: MCPToolArguments, in context: MCPToolContext, studio: PageShotsStudio
    ) async throws -> Result<PageShotsMCPRun, PageShotsMCPRefusal> {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let page = try arguments.string("page").trimmingCharacters(in: .whitespacesAndNewlines)
        let target = "\(app.name) · \(page) · screenshots"
        let key = ProductPageBrief.key(page)
        guard let run = studio.runs.values.first(where: { $0.appID == app.id && ($0.pageID == page || $0.key.page == key) }) else {
            return .failure(PageShotsMCPRefusal(target: target, message: String(localized: """
            Nobody pressed Make Screenshots for This Page on “\(page)” in Atlas. The person starts it from the page's \
            screenshots in Product Pages; until then, describe the screenshots in propose_product_page's screens.
            """)))
        }
        // As the run makes its set: its Look and the screens captured again.
        let source = try await PageShotsSource.load(app: app, services: context.workspace.services.screenshots).applying(run)
        return .success(PageShotsMCPRun(app: app, run: run, source: source))
    }

    var target: String { "\(app.name) · \(run.pageName) · screenshots" }
}
