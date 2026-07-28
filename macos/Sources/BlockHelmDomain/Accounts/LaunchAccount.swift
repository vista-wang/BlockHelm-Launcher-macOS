/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

/// Session used when launching the game process.
public struct LaunchAccount: Sendable, Equatable {
    public var username: String
    public var uuid: String
    public var accessToken: String
    public var userType: String
    public var kind: LauncherAccountKind

    public init(
        username: String,
        uuid: String,
        accessToken: String = "0",
        userType: String = "legacy",
        kind: LauncherAccountKind = .offline
    ) {
        self.username = username
        self.uuid = uuid
        self.accessToken = accessToken
        self.userType = userType
        self.kind = kind
    }

    public static func offline(from account: LauncherAccountRecord) -> LaunchAccount {
        let uuid = account.uuid ?? OfflineUuid.standard(from: account.displayName)
        return LaunchAccount(
            username: account.displayName,
            uuid: uuid,
            accessToken: "0",
            userType: "legacy",
            kind: .offline
        )
    }
}

public enum OfflineUuid {
    /// Mojang offline UUID: MD5("OfflinePlayer:" + name) with version/variant bits.
    public static func standard(from name: String) -> String {
        let data = Data("OfflinePlayer:\(name)".utf8)
        var digest = [UInt8](repeating: 0, count: 16)
        data.withUnsafeBytes { buffer in
            // Use CryptoKit-compatible fallback via CommonCrypto-style MD5 when available;
            // for Domain purity we implement a small MD5 here via Foundation if needed.
            _ = buffer
        }
        digest = md5(data)
        digest[6] = (digest[6] & 0x0F) | 0x30
        digest[8] = (digest[8] & 0x3F) | 0x80
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Minimal MD5 for offline UUID (Domain has no external deps).
private func md5(_ data: Data) -> [UInt8] {
    // FIPS-180 style compact MD5
    var message = [UInt8](data)
    let bitLen = UInt64(message.count) * 8
    message.append(0x80)
    while message.count % 64 != 56 {
        message.append(0)
    }
    var lenBytes = [UInt8](repeating: 0, count: 8)
    for i in 0..<8 {
        lenBytes[i] = UInt8((bitLen >> (8 * i)) & 0xFF)
    }
    message.append(contentsOf: lenBytes)

    var a0: UInt32 = 0x67452301
    var b0: UInt32 = 0xEFCDAB89
    var c0: UInt32 = 0x98BADCFE
    var d0: UInt32 = 0x10325476

    let s: [Int] = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
    ]
    let k: [UInt32] = (0..<64).map { i in
        UInt32(floor(abs(sin(Double(i + 1))) * 4294967296.0))
    }

    func leftRotate(_ x: UInt32, _ c: Int) -> UInt32 {
        (x << c) | (x >> (32 - c))
    }

    for chunkStart in stride(from: 0, to: message.count, by: 64) {
        var m = [UInt32](repeating: 0, count: 16)
        for i in 0..<16 {
            let j = chunkStart + i * 4
            m[i] = UInt32(message[j])
                | (UInt32(message[j + 1]) << 8)
                | (UInt32(message[j + 2]) << 16)
                | (UInt32(message[j + 3]) << 24)
        }
        var a = a0, b = b0, c = c0, d = d0
        for i in 0..<64 {
            var f: UInt32 = 0
            var g = 0
            switch i {
            case 0..<16:
                f = (b & c) | ((~b) & d)
                g = i
            case 16..<32:
                f = (d & b) | ((~d) & c)
                g = (5 * i + 1) % 16
            case 32..<48:
                f = b ^ c ^ d
                g = (3 * i + 5) % 16
            default:
                f = c ^ (b | (~d))
                g = (7 * i) % 16
            }
            let temp = d
            d = c
            c = b
            b = b &+ leftRotate(a &+ f &+ k[i] &+ m[g], s[i])
            a = temp
        }
        a0 = a0 &+ a
        b0 = b0 &+ b
        c0 = c0 &+ c
        d0 = d0 &+ d
    }

    func bytes(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
    return bytes(a0) + bytes(b0) + bytes(c0) + bytes(d0)
}
