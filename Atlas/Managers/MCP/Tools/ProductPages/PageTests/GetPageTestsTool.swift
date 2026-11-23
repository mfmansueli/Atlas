//
//  GetPageTestsTool.swift
//  Atlas
//

import Foundation

/// `get_page_tests`: the app's Product Page Optimization tests in App
/// Store Connect (state, traffic, dates, and the treatments of the ones
/// not over, with their languages and artwork), what the header and the
/// search results can be tested with now (the artwork Autopilot made, the
/// run's variant, images in the app's library), and the tests assistants
/// proposed. Results aren't in the API: it says so.
struct GetPageTestsTool: MCPTool {
    var provider: MCPPageTests.Provider = MCPPageTests.provider(in:)

    let definition = MCPToolDefinition(
        name: "get_page_tests",
        title: "Get Product Page Optimization tests",
        description: """
        Reads an app's Product Page Optimization (A/B) tests of the header and search results artwork. tests: App \
        Store Connect's tests (testId, name, state, isOver, trafficProportion, reviewRequired, startDate, endDate), \
        with the treatments, languages and placed artwork (assetId) of the tests not over, or of the one testId \
        names; noTests says so when there are none. results is always null: the API doesn't give results (resultsNote). \
        inProgress is the test in the way of a new one (one at a time). testable, per placement (header, \
        searchResults): the artwork Autopilot made (languages, those still waiting in Review & Push), the run's \
        variant (change, languages, errors) or why there's none, and library: images already in the app's App Asset \
        Library a treatment can use (assetId, size, the locale its name carries). proposals: the tests assistants \
        proposed and their status (pending, made, dismissed, withdrawn). Then propose one with propose_page_test.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "testId": MCPToolDefinition.string("Read this test's treatments too, even when it's over."),
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let pageTests = try await MCPPageTests.load(app: arguments.string("appId"), in: context.workspace, provider: provider)
        let testID = try arguments.optionalString("testId")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tests = try await pageTests.tests()
        if let testID, !testID.isEmpty, !tests.contains(where: { $0.id == testID }) {
            throw MCPToolError.notFound(String(localized: "\(pageTests.app.name) has no test “\(testID)”. Leave testId out to list them."))
        }
        var testsJSON: [JSONValue] = []
        for test in tests {
            let reads = !test.isFinished || test.id == testID
            let treatments = reads ? try? await pageTests.treatments(of: test) : nil
            testsJSON.append(MCPPageTestsJSON.test(test, treatments: treatments))
        }
        let library = await pageTests.library()
        let refData = await pageTests.refData()
        let proposer = ProductPageTestProposer(
            extras: pageTests.extras, primaryLocale: pageTests.primary.code, tests: tests,
            queuedDeletions: ProductPageTestDeletion.queuedExperimentIDs(in: context.workspace.changes.changes(for: pageTests.app.id)),
            client: context.clientName, now: .now
        )
        var result: [String: JSONValue] = [
            "appId": .string(pageTests.app.id),
            "tests": .array(testsJSON),
            "resultsNote": .string(MCPPageTestsJSON.resultsNote),
            "testable": .array(pageTests.readiness.map { readiness in
                MCPPageTestsJSON.testable(
                    readiness, canAskForVariant: pageTests.canAskForVariant, library: library.files, refData: refData
                )
            }),
            "proposals": .array((pageTests.extras?.testProposals ?? []).map(MCPPageTestsJSON.proposal)),
            "rules": .string(MCPPageTestsJSON.rules),
        ]
        if tests.isEmpty {
            result["noTests"] = .string(String(localized: "\(pageTests.app.name) has no Product Page Optimization tests in App Store Connect yet."))
        }
        if let blocking = proposer.blockingTest {
            var inProgress: [String: JSONValue] = [
                "testId": .string(blocking.id), "name": blocking.name.map(JSONValue.string) ?? .null, "stateTitle": .string(blocking.stateTitle),
            ]
            if proposer.queuedDeletions.contains(blocking.id) { inProgress["deletionQueued"] = true }
            result["inProgress"] = .object(inProgress)
            result["canProposeNow"] = .bool(blocking.isDraft && proposer.queuedDeletions.contains(blocking.id))
        } else {
            result["inProgress"] = .null
            result["canProposeNow"] = true
        }
        if let error = library.error { result["libraryError"] = .string(error) }
        return .read(.object(result), target: pageTests.target)
    }
}
