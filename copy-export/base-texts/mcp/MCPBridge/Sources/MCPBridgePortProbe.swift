//
//  MCPBridgePortProbe.swift
//  atlas-mcp
//

import Darwin
import Foundation

/// Whether anything listens on a port, with a plain socket. Once a process
/// has connected to a port, URLSession reports a refused connection there
/// as "connection lost" (-1005), in any session; a socket still says
/// refused.
enum MCPBridgePortProbe {
    /// True when something at `url`'s host and port accepts a connection,
    /// or when that can't be told.
    static func isListening(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false), let port = url.port else { return true }
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &info) == 0, let first = info else { return true }
        defer { freeaddrinfo(first) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let address = cursor {
            let socket = Darwin.socket(address.pointee.ai_family, address.pointee.ai_socktype, address.pointee.ai_protocol)
            if socket >= 0 {
                let connected = connect(socket, address.pointee.ai_addr, address.pointee.ai_addrlen) == 0
                close(socket)
                if connected { return true }
            }
            cursor = address.pointee.ai_next
        }
        return false
    }
}
