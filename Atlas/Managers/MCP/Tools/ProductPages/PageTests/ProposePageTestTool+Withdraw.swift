//
//  ProposePageTestTool+Withdraw.swift
//  Atlas
//

import Foundation

/// `propose_page_test`'s other actions: deleting a draft test, queued in
/// Review & Push, and taking back the caller's own proposal.
extension ProposePageTestTool {
    func deleteDraft(_ arguments: MCPToolArguments, pageTests: MCPPageTests, context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let testID = try arguments.optionalString("testId")?.trimmingCharacters(in: .whitespacesAndNewlines), !testID.isEmpty else {
            throw MCPToolError.invalidArgument(name: "testId", expected: String(localized: "the draft's testId from get_page_tests"))
        }
        let reason = try arguments.optionalString("reason")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target = "\(pageTests.target) · " + String(localized: "delete \(testID)")
        guard !reason.isEmpty else {
            return .refused(String(localized: "Send reason: why delete it, in a sentence the person reads."), target: target, details: ["code": "no_reason"])
        }
        guard let test = try await pageTests.tests().first(where: { $0.id == testID }) else {
            return .refused(
                String(localized: "\(pageTests.app.name) has no test “\(testID)”. Use get_page_tests."), target: target, details: ["code": "unknown_test"]
            )
        }
        guard test.isDraft else {
            return .refused(String(localized: """
            “\(test.name ?? test.id)” is \(test.stateTitle), not a draft: only a draft can be deleted from Atlas. The person stops \
            a running test in App Store Connect (the API can’t stop one).
            """), target: target, details: ["code": "not_a_draft"])
        }
        let evidence = try Self.evidence(arguments)
        let note = ([reason] + (evidence.isEmpty ? [] : [evidence.joined(separator: "; ")])).joined(separator: " · ")
        let change = ProductPageTestDeletion.change(appID: pageTests.app.id, experiment: test, source: context.source, reason: note)
        context.workspace.changes.upsert(change)
        return MCPToolOutcome(
            result: [
                "status": "queued",
                "changeId": .string(change.id),
                "next": "Deleting it waits in Review & Push: it's deleted when the person pushes. A new test can be proposed now; it waits for that push.",
            ],
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }

    func withdraw(_ arguments: MCPToolArguments, pageTests: inout MCPPageTests, context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let id = try arguments.optionalString("proposalId")?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            throw MCPToolError.invalidArgument(name: "proposalId", expected: String(localized: "your proposal's id, e.g. pt-3f2a9c1b"))
        }
        let target = "\(pageTests.target) · " + String(localized: "withdraw \(id)")
        guard let proposal = pageTests.extras?.testProposal(id: id) else {
            return .refused(String(localized: "No proposed test “\(id)” for \(pageTests.app.name). Use get_page_tests."), target: target, details: ["code": "unknown_proposal"])
        }
        guard proposal.client == context.clientName else {
            return .refused(String(localized: "Suggested by \(proposal.client), not by you: left for the person."), target: target, details: ["code": "not_yours"])
        }
        guard proposal.isOpen else {
            let why = proposal.status == .made
                ? String(localized: "The person made the test already: it’s theirs to change in App Store Connect.")
                : String(localized: "It’s \(proposal.status.rawValue) already.")
            return .refused(why, target: target, details: ["code": "decided"])
        }
        let date = now()
        try await pageTests.changeExtras(now: date) { $0.decideTestProposal(id: id, status: .withdrawn, at: date) }
        return MCPToolOutcome(
            result: ["status": "withdrawn", "proposalId": .string(id)], isError: false, logLines: [.init(target: target, outcome: .proposed)]
        )
    }
}
