//
//  Gzip.swift
//  Atlas
//

import Foundation

/// Unpacks the gzip files Apple's reports come as. Foundation only inflates
/// raw DEFLATE, so the gzip header and trailer are stepped over here.
enum Gzip {
    /// The file's contents; data that isn't gzip comes back as it is, and
    /// nil means it was gzip but couldn't be inflated.
    static func inflate(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 else { return data }
        let flags = bytes[3]
        var index = 10
        // FEXTRA: a two-byte length, then that many bytes.
        if flags & 0x04 != 0 {
            guard index + 2 <= bytes.count else { return nil }
            index += 2 + Int(bytes[index]) + Int(bytes[index + 1]) << 8
        }
        // FNAME and FCOMMENT: zero-terminated strings.
        for flag in [UInt8(0x08), 0x10] where flags & flag != 0 {
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        // FHCRC: two bytes.
        if flags & 0x02 != 0 { index += 2 }
        guard index < bytes.count - 8 else { return nil }
        let deflated = Data(bytes[index..<(bytes.count - 8)])
        return try? (deflated as NSData).decompressed(using: .zlib) as Data
    }
}
