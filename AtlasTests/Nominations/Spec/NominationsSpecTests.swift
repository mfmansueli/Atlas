//
//  NominationsSpecTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Everything Atlas sends to and reads from `/v1/nominations` against
/// Apple's OpenAPI spec (`NominationsAPISpec`): each query parameter, each
/// value of a list and each limit; the attributes and relationships of a
/// create, update, submit and archive; and the fields Atlas decodes.
@Suite("Nominations · App Store Connect spec")
struct NominationsSpecTests {
    typealias Spec = NominationsAPISpec
    typealias Data = DebugNominationsData

    static let queries: [(name: String, items: [URLQueryItem])] = AppStoreConnectClient.nominationStates.flatMap { state in
        [
            ("full \(state)", AppStoreConnectClient.nominationsQuery(state: state, appID: "6450000001")),
            ("plain \(state)", AppStoreConnectClient.nominationsPlainQuery(state: state, appID: "6450000001")),
        ]
    } + [("drafts lookup", lookupItems)]

    static var lookupItems: [URLQueryItem] {
        URLComponents(string: AppStoreConnectClient.draftNominationsPath(appID: "6450000001"))?.queryItems ?? []
    }

    /// The problems of one query against the spec, e.g. "fields[actors]:
    /// actorType is refused by Apple".
    static func problems(_ items: [URLQueryItem]) -> [String] {
        var problems: [String] = []
        let names = items.map(\.name)
        if Set(names).count != names.count { problems.append("a parameter is sent twice") }
        for (name, parameter) in Spec.listParameters where parameter.required && !names.contains(name) {
            problems.append("\(name) is required")
        }
        for item in items {
            guard let parameter = Spec.listParameters[item.name] else {
                problems.append("\(item.name) isn't a parameter")
                continue
            }
            let value = item.value ?? ""
            let values = value.split(separator: ",").map(String.init)
            if values.isEmpty { problems.append("\(item.name) is empty") }
            if let allowed = parameter.values {
                for value in values where !allowed.contains(value) {
                    problems.append("\(item.name): \(value) isn't allowed")
                }
            }
            for value in values where Spec.refusedByApple[item.name]?.contains(value) == true {
                problems.append("\(item.name): \(value) is refused by Apple")
            }
            if let maximum = parameter.maximum, Int(value).map({ (1...maximum).contains($0) }) != true {
                problems.append("\(item.name)=\(value) isn't 1–\(maximum)")
            }
        }
        return problems
    }

    @Test(arguments: queries.map(\.name))
    func everyQueryParameterIsOneTheSpecAllows(_ name: String) throws {
        let query = try #require(Self.queries.first { $0.name == name })
        #expect(Self.problems(query.items).isEmpty, "\(Self.problems(query.items))")
    }

    @Test func theCheckCatchesWhatAppleRefused() {
        let refused = [
            URLQueryItem(name: "filter[state]", value: "DRAFT"),
            URLQueryItem(name: "fields[actors]", value: "actorType,userFirstName"),
            URLQueryItem(name: "fields[apps]", value: "title"),
            URLQueryItem(name: "limit", value: "500"),
            URLQueryItem(name: "filter[app]", value: "1"),
        ]
        #expect(Self.problems(refused) == [
            "fields[actors]: actorType is refused by Apple",
            "fields[apps]: title isn't allowed",
            "limit=500 isn't 1–200",
            "filter[app] isn't a parameter",
        ])
        #expect(Self.problems([URLQueryItem(name: "limit", value: "200")]) == ["filter[state] is required"])
    }

    @Test func noQueryAsksForActorFields() {
        for query in Self.queries {
            #expect(!query.items.contains { $0.name == "fields[actors]" }, "\(query.name)")
        }
    }

    @Test func thePlainQueryStillLinksAppsEventsAndTerritories() {
        let include = AppStoreConnectClient.nominationsPlainQuery(state: "DRAFT", appID: "1").first { $0.name == "include" }?.value
        #expect(include == "relatedApps,inAppEvents,supportedTerritories")
        #expect(!AppStoreConnectClient.nominationsPlainQuery(state: "DRAFT", appID: "1").contains { $0.name.hasPrefix("fields[") })
    }

    // MARK: - Requests

    private static func data(_ body: Foundation.Data) throws -> [String: Any] {
        let root = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try #require(root["data"] as? [String: Any])
    }

    private static func keys(_ object: Any?) -> Set<String> {
        Set((object as? [String: Any])?.keys.map(\.self) ?? [])
    }

    @Test func aCreateSendsWhatTheSpecTakes() throws {
        var content = Data.draft.content
        content.territories = ["USA"]
        content.publishEnd = Data.day(2026, 12, 20)
        content.notes = "Built around the event."
        let data = try Self.data(NominationRequestBody.create(content))
        #expect(data["type"] as? String == "nominations")
        let attributes = Self.keys(data["attributes"])
        #expect(attributes.isSubset(of: Spec.createAttributes), "\(attributes.subtracting(Spec.createAttributes))")
        #expect(Spec.createRequiredAttributes.isSubset(of: attributes))
        let relationships = Self.keys(data["relationships"])
        #expect(relationships.isSubset(of: Spec.createRelationships))
        #expect(Spec.createRequiredRelationships.isSubset(of: relationships))
        let values = try #require(data["attributes"] as? [String: Any])
        #expect(Set(values["deviceFamilies"] as? [String] ?? []).isSubset(of: Spec.deviceFamilies))
        #expect(Spec.types.contains(values["type"] as? String ?? ""))
    }

    @Test func anUpdateSubmitAndArchiveSendWhatTheSpecTakes() throws {
        let bodies = try [
            NominationRequestBody.update(id: "N1", Data.draft.content),
            NominationRequestBody.submit(id: "N1"),
            NominationRequestBody.archive(id: "N1"),
        ]
        for body in bodies {
            let data = try Self.data(body)
            #expect(data["id"] as? String == "N1")
            #expect(data["type"] as? String == "nominations")
            let attributes = Self.keys(data["attributes"])
            #expect(attributes.isSubset(of: Spec.updateAttributes), "\(attributes.subtracting(Spec.updateAttributes))")
            #expect(Self.keys(data["relationships"]).isSubset(of: Spec.updateRelationships))
        }
    }

    @Test func theChangesUseTheSpecsPaths() throws {
        let builder = NominationChangeBuilder(appID: Data.lumen)
        let remote = Data.winter
        let changes = try [builder.update(remote, from: remote.content), builder.archive(remote), builder.delete(remote)]
        #expect(changes.flatMap(\.requests).map(\.path).allSatisfy { $0 == "/v1/nominations/\(remote.id)" })
        #expect(try builder.create(Data.draft).requests.map(\.path) == ["/v1/nominations"])
    }

    // MARK: - What's read

    private static func labels(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    @Test func theDecodedFieldsAreTheSpecs() {
        let attributes = Self.labels(NominationAttributes())
        #expect(attributes.isSubset(of: Spec.nominationAttributes), "\(attributes.subtracting(Spec.nominationAttributes))")
        let relationships = Self.labels(NominationsDocument.Relationships())
        #expect(relationships.isSubset(of: Spec.nominationRelationships))
        let included = Self.labels(NominationIncludedAttributes())
        let known = Spec.actorAttributes.union(Spec.appAttributes).union(Spec.appEventAttributes).union(Spec.territoryAttributes)
        #expect(included.isSubset(of: known), "\(included.subtracting(known))")
    }

    @Test func theEnumsAreTheSpecs() {
        #expect(Set(NominationType.allCases.map(\.rawValue)) == Spec.types)
        #expect(Set(NominationState.allCases.map(\.rawValue)) == Spec.states)
        #expect(Set(AppStoreConnectClient.nominationStates) == Spec.states)
        #expect(Set(NominationDevice.allCases.map(\.rawValue)) == Spec.deviceFamilies)
    }
}
