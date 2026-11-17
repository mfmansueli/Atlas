//
//  HTTPReply+Testing.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

extension HTTPReply {
    /// The plain response, or nil for an event stream.
    var response: HTTPResponse? {
        if case let .response(response) = self { return response }
        return nil
    }

    /// The event stream, or nil for a plain response.
    var eventStream: HTTPEventStream? {
        if case let .events(stream) = self { return stream }
        return nil
    }
}
