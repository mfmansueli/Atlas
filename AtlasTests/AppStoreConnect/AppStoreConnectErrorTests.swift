//
//  AppStoreConnectErrorTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("AppStoreConnectError")
struct AppStoreConnectErrorTests {
    private func body(detail: String?, title: String = "Title") -> Data {
        let detailField = detail.map { #","detail":"\#($0)""# } ?? ""
        return Data(#"{"errors":[{"status":"0","code":"CODE","title":"\#(title)"\#(detailField)}]}"#.utf8)
    }

    @Test(arguments: [
        (401, AppStoreConnectError.unauthorized),
        (403, .forbidden(detail: "Detail")),
        (404, .notFound(detail: "Detail")),
        (429, .rateLimited),
        (500, .server(statusCode: 500, code: "CODE", detail: "Detail")),
    ])
    func statusCodesMapToCases(statusCode: Int, expected: AppStoreConnectError) {
        #expect(AppStoreConnectError(statusCode: statusCode, body: body(detail: "Detail")) == expected)
    }

    @Test(arguments: [409, 422])
    func refusedValuesKeepApplesCode(statusCode: Int) {
        let error = AppStoreConnectError(statusCode: statusCode, body: body(detail: "Not available."))
        #expect(error == .rejected(statusCode: statusCode, code: "CODE", detail: "Not available."))
        #expect(error.pushFailureText == "CODE — Not available.")
    }

    @Test func serverErrorsKeepApplesCode() {
        let error = AppStoreConnectError(statusCode: 500, body: body(detail: "Boom"))
        #expect(error.pushFailureText == "CODE — Boom")
        #expect(AppStoreConnectError.server(statusCode: 503, detail: nil).pushFailureText == "HTTP 503")
    }

    @Test func titleStandsInForAMissingDetail() {
        #expect(AppStoreConnectError(statusCode: 403, body: body(detail: nil, title: "Forbidden")) == .forbidden(detail: "Forbidden"))
    }

    @Test func unreadableBodyHasNoDetail() {
        #expect(AppStoreConnectError(statusCode: 502, body: Data("<html>".utf8)) == .server(statusCode: 502, detail: nil))
    }

    /// SimProps's Submit showed only "This resource cannot be reviewed,
    /// please check associated errors to see why.": the reasons are in
    /// `meta.associatedErrors`, by resource.
    @Test func associatedErrorsSayWhy() throws {
        let body = Data(#"""
        {"errors":[{"status":"409","code":"STATE_ERROR.ENTITY_STATE_INVALID","title":"appStoreVersions with id 'v14' is not in valid state.",
        "detail":"This resource cannot be reviewed, please check associated errors to see why.",
        "meta":{"associatedErrors":{
          "/v1/appStoreVersions/v14":[
            {"code":"ENTITY_ERROR.ATTRIBUTE.REQUIRED","status":"409","title":"An attribute value is required.",
             "detail":"You must provide a value for the attribute 'copyright' with this request"}],
          "/v1/appScreenshotSets/s1/appScreenshots":[{"code":"ENTITY_ERROR.RELATIONSHIP.REQUIRED","status":"409","title":"Screenshots are required."}],
          "/v1/apps/42":[{"code":"ENTITY_ERROR.ATTRIBUTE.REQUIRED","status":"409","title":"x",
             "detail":"You must provide a value for the attribute 'copyright' with this request"}]
        }}}]}
        """#.utf8)
        let error = AppStoreConnectError(statusCode: 409, body: body)
        let reasons = """
        This resource cannot be reviewed, please check associated errors to see why.
        • Screenshots are required.
        • You must provide a value for the attribute 'copyright' with this request
        """
        #expect(error == .rejected(statusCode: 409, code: "STATE_ERROR.ENTITY_STATE_INVALID", detail: reasons))
        let message = try #require(error.errorDescription)
        #expect(message.hasSuffix(reasons))
        #expect(error.pushFailureText == "STATE_ERROR.ENTITY_STATE_INVALID — \(reasons)")
    }

    @Test func manyReasonsAreCounted() throws {
        let reasons = (1...9).map { #"{"code":"C","status":"409","title":"T","detail":"Reason \#($0)."}"# }.joined(separator: ",")
        let body = Data(#"{"errors":[{"status":"409","code":"C","title":"T","detail":"Top.","meta":{"associatedErrors":{"/v1/x":[\#(reasons)]}}}]}"#.utf8)
        let detail = try #require(AppStoreConnectError.detail(of: JSONDecoder().decode(AppStoreConnectErrorResponse.self, from: body).errors.first))
        let lines = detail.components(separatedBy: "\n")
        #expect(lines.count == 1 + AppStoreConnectError.reasonsShown + 1)
        #expect(lines.last == "and 3 more")
    }

    @Test func aMetaOfAnotherShapeKeepsTheError() {
        let body = Data(#"{"errors":[{"status":"409","code":"C","title":"T","detail":"Top.","meta":{"associatedErrors":"none","other":1}}]}"#.utf8)
        #expect(AppStoreConnectError(statusCode: 409, body: body) == .rejected(statusCode: 409, code: "C", detail: "Top."))
    }

    @Test func messagePutsApplesDetailUnderDetails() throws {
        let message = try #require(AppStoreConnectError.forbidden(detail: "Missing role.").errorDescription)
        #expect(message == "This API key isn't allowed to do that. Team keys need the Admin or App Manager role.\nDetails: Missing role.")
    }

    @Test func aServerFailureSaysToTryAgainAndKeepsApplesTextInDetails() {
        let error = AppStoreConnectError.server(statusCode: 503, code: "UNEXPECTED_ERROR", detail: "Try later.")
        #expect(error.errorDescription == "App Store Connect had a problem (503). Try again in a minute.\nDetails: Try later.")
    }

    @Test func aRefused4xxRequestIsNotCalledAProblemOnApplesSide() {
        let error = AppStoreConnectError.server(statusCode: 400, code: "PARAMETER_ERROR", detail: nil)
        #expect(error.errorDescription == "App Store Connect refused the request (400).")
    }
}
