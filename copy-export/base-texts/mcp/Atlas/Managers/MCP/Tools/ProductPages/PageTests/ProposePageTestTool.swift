//
//  ProposePageTestTool.swift
//  Atlas
//

import Foundation

/// `propose_page_test`: an assistant proposes a Product Page Optimization
/// test of the header or the search results image. It's checked like the
/// sheet checks one (one test at a time, a variant without Apple's
/// errors, languages the treatment has, a library image of a size Apple
/// takes) and waits in Review & Push's header and search card, where the
/// person opens it in “Test with Product Page Optimization…”, prefilled,
/// and creates it. Without a variant yet, Atlas asks the Autopilot run for
/// one. `action: deleteDraft` queues deleting a draft test as a change in
/// Review & Push; `action: withdraw` takes back the caller's own proposal.
/// Nothing reaches App Store Connect until the person does it.
struct ProposePageTestTool: MCPTool {
    var provider: MCPPageTests.Provider = MCPPageTests.provider(in:)
    var now: @MainActor () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_page_test",
        title: "Propose a Product Page Optimization test",
        description: """
        Proposes a Product Page Optimization (A/B) test of the header or the search results image, from \
        get_page_tests: name (or Atlas names it "Header: Interface vs Outcome"), placement (header or searchResults: \
        one per test), trafficProportion (percent of visitors who see the treatment, 1–100, default 50), treatment \
        (variant: the Autopilot run's variant for that placement, see testable.variant; library: images already in \
        the app's library, with assets [{locale, assetId}] from testable.library), locales (default: every language \
        the treatment has), startsTest (true sends it to App Review once made; default false keeps a draft), and a \
        reason with evidence. It waits in Review & Push for the person, who opens it prefilled and creates it; \
        status "queued" with proposalId. With treatment variant and no variant yet, Atlas asks the run for one \
        (variant: "asked"): call next_step, design it, send it with propose_artwork_variant. Refused (status \
        "refused", code, reason) while another test isn't over (Apple runs one at a time), for a variant with \
        Apple's errors, a language the treatment lacks, or a library image that isn't processed or the right size. \
        Sending the same placement again replaces your open proposal. action: deleteDraft with testId queues \
        deleting a draft test as a change in Review & Push (a running test can't be stopped through the API); \
        action: withdraw with proposalId takes back your own pending proposal.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "action": ["type": "string", "enum": ["create", "deleteDraft", "withdraw"], "description": "create (default), deleteDraft or withdraw."],
                "name": MCPToolDefinition.string("The test's name in App Store Connect, up to 64 characters."),
                "placement": ["type": "string", "enum": ["header", "searchResults"], "description": "What the test changes."],
                "trafficProportion": ["type": "integer", "description": "Percent of visitors who see the treatment, 1–100."],
                "treatment": ["type": "string", "enum": ["variant", "library"], "description": "Where the treatment's image comes from."],
                "assets": [
                    "type": "array",
                    "items": MCPToolDefinition.schema(
                        ["locale": MCPToolDefinition.string("e.g. de-DE"), "assetId": MCPToolDefinition.string("From testable.library.")],
                        required: ["locale", "assetId"]
                    ),
                    "description": "treatment library: one image per language.",
                ],
                "locales": ["type": "array", "items": ["type": "string"], "description": "The languages to test; default all."],
                "startsTest": ["type": "boolean", "description": "Send it to App Review once made. Default false (a draft)."],
                "reason": MCPToolDefinition.string("Why this test, in a sentence the person reads."),
                "evidence": ["type": "array", "items": evidenceSchema, "description": "What it's based on."],
                "testId": MCPToolDefinition.string("deleteDraft: the draft's testId from get_page_tests."),
                "proposalId": MCPToolDefinition.string("withdraw: your proposal's id."),
            ],
            required: ["appId"]
        ),
        proposalKind: .artwork
    )

    private static let evidenceSchema = MCPToolDefinition.schema(
        ["kind": MCPToolDefinition.string("analytics, reviews, design, …"), "ref": MCPToolDefinition.string("What to look at.")],
        required: ["kind", "ref"]
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        var pageTests = try await MCPPageTests.load(app: arguments.string("appId"), in: context.workspace, provider: provider)
        switch try arguments.optionalString("action") ?? "create" {
        case "create": return try await create(arguments, pageTests: &pageTests, context: context)
        case "deleteDraft": return try await deleteDraft(arguments, pageTests: pageTests, context: context)
        case "withdraw": return try await withdraw(arguments, pageTests: &pageTests, context: context)
        default: throw MCPToolError.invalidArgument(name: "action", expected: String(localized: "create, deleteDraft or withdraw"))
        }
    }

    private func create(_ arguments: MCPToolArguments, pageTests: inout MCPPageTests, context: MCPToolContext) async throws -> MCPToolOutcome {
        let input = try Self.input(arguments)
        let tests = try await pageTests.tests()
        var proposer = ProductPageTestProposer(
            extras: pageTests.extras, primaryLocale: pageTests.primary.code, tests: tests,
            queuedDeletions: ProductPageTestDeletion.queuedExperimentIDs(in: context.workspace.changes.changes(for: pageTests.app.id)),
            canAskForVariant: pageTests.canAskForVariant, client: context.clientName, now: now()
        )
        // Only a library treatment reads the library.
        if input.treatment == "library" {
            proposer.library = await pageTests.library().files
            proposer.refData = await pageTests.refData()
        }
        let target = "\(pageTests.target) · \(input.placement.title)"
        switch proposer.propose(input) {
        case let .refused(code, reason):
            return .refused(reason, target: target, details: ["code": .string(code)])
        case let .queued(proposal, asksForVariant, notes):
            if asksForVariant {
                let readiness = ProductPageTestReadiness(extras: pageTests.extras, placement: input.placement, primary: pageTests.primary.code)
                guard let kind = readiness.kind, pageTests.services.autopilot?.requestVariant(
                    appID: pageTests.app.id, role: input.placement == .header ? .header : .search, kind: kind
                ) == true else {
                    return .refused(String(localized: "The Autopilot run couldn’t be asked for a variant. Ask the person to open its run."), target: target)
                }
            }
            var replaced: ProductPageTestProposal.ID?
            try await pageTests.changeExtras(now: now()) { replaced = $0.receive(proposal) }
            var result: [String: JSONValue] = [
                "status": "queued",
                "proposalId": .string(proposal.id),
                "proposal": MCPPageTestsJSON.proposal(proposal),
                "next": .string(asksForVariant
                    ? String(localized: """
                    Atlas asked the Autopilot run for the variant: call next_step (it says design_variant) and send it with \
                    propose_artwork_variant. The test waits in Review & Push for the person, who creates it once the variant is in.
                    """)
                    : String(localized: "It waits in Review & Push: the person opens it, checks it and creates the test.")),
            ]
            if asksForVariant { result["variant"] = "asked" }
            if let replaced { result["replaced"] = .string(replaced) }
            if !notes.isEmpty { result["notes"] = .array(notes.map(JSONValue.string)) }
            return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: "\(target) · \(proposal.name)", outcome: .proposed)])
        }
    }

    /// The create arguments, checked for type; the proposer checks the rest.
    static func input(_ arguments: MCPToolArguments) throws -> ProductPageTestProposer.Input {
        guard let placementName = try arguments.optionalString("placement") else {
            throw MCPToolError.invalidArgument(name: "placement", expected: String(localized: "header or searchResults"))
        }
        let aliases: [String: ProductPageTestPlacement] = ["search": .searchResults, "searchresults": .searchResults, "header": .header]
        guard let placement = ProductPageTestPlacement(rawValue: placementName) ?? aliases[placementName.lowercased()] else {
            throw MCPToolError.invalidArgument(name: "placement", expected: String(localized: "header or searchResults (one per test)"))
        }
        var assets: [String: String] = [:]
        for item in try arguments.optionalArray("assets") ?? [] {
            guard let code = item["locale"]?.stringValue, let assetID = item["assetId"]?.stringValue else {
                throw MCPToolError.invalidArgument(name: "assets", expected: String(localized: "a list of {locale, assetId} objects"))
            }
            guard let locale = StoreLocaleCatalog.resolve(code).locale else {
                throw MCPToolError.notFound(String(localized: "“\(code)” isn’t an App Store locale. Use codes such as de-DE, ja or pt-BR."))
            }
            assets[locale.code] = assetID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let locales = try arguments.optionalStrings("locales")?.map { code in
            guard let locale = StoreLocaleCatalog.resolve(code).locale else {
                throw MCPToolError.notFound(String(localized: "“\(code)” isn’t an App Store locale. Use codes such as de-DE, ja or pt-BR."))
            }
            return locale.code
        }
        return try ProductPageTestProposer.Input(
            name: arguments.optionalString("name"), placement: placement, trafficProportion: arguments.optionalInt("trafficProportion"),
            treatment: arguments.optionalString("treatment") ?? "variant", assets: assets, locales: locales,
            startsTest: arguments.optionalBool("startsTest") ?? false, reason: arguments.optionalString("reason") ?? "",
            evidence: evidence(arguments)
        )
    }

    /// `evidence` as lines: "analytics: search conversion 2.1%".
    static func evidence(_ arguments: MCPToolArguments) throws -> [String] {
        try (arguments.optionalArray("evidence") ?? []).map { entry in
            if let text = entry.stringValue { return text }
            guard let kind = entry["kind"]?.stringValue, let ref = entry["ref"]?.stringValue else {
                throw MCPToolError.invalidArgument(name: "evidence", expected: String(localized: "a list of {kind, ref} objects"))
            }
            return "\(kind): \(ref)"
        }
    }
}
