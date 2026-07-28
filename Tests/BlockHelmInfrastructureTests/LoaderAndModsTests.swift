/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import XCTest
@testable import BlockHelmInfrastructure
@testable import BlockHelmDomain

final class LoaderCatalogTests: XCTestCase {
    func testNeoForgePrefixMapping() {
        XCTAssertEqual(LoaderCatalogServiceImpl.neoForgePrefix(for: "1.21.1"), "21.1.")
        XCTAssertEqual(LoaderCatalogServiceImpl.neoForgePrefix(for: "1.20.4"), "20.4.")
        XCTAssertEqual(LoaderCatalogServiceImpl.neoForgePrefix(for: "1.21"), "21.0.")
    }

    func testParseMavenVersions() {
        let xml = """
        <metadata><versioning><versions>
          <version>1.20.1-47.2.0</version>
          <version>1.20.1-47.3.0</version>
        </versions></versioning></metadata>
        """
        let versions = LoaderCatalogServiceImpl.parseMavenVersions(xml)
        XCTAssertEqual(versions, ["1.20.1-47.2.0", "1.20.1-47.3.0"])
    }
}

final class LocalModServiceTests: XCTestCase {
    func testEnableDisableRoundTrip() async throws {
        let modsParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-inst-\(UUID().uuidString)", isDirectory: true)
        let modsDir = modsParent.appendingPathComponent("mods", isDirectory: true)
        try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
        let modJar = modsDir.appendingPathComponent("demo.jar")
        try Data([0x50, 0x4B]).write(to: modJar)
        defer { try? FileManager.default.removeItem(at: modsParent) }

        let service = LocalContentServiceImpl()
        let inst = GameInstance(
            name: "test",
            minecraftVersion: "1.20.1",
            loader: .fabric,
            versionName: "test",
            instanceDirectory: modsParent.path
        )
        var mods = try await service.list(instance: inst, kind: .mod)
        XCTAssertEqual(mods.count, 1)
        XCTAssertTrue(mods[0].isEnabled)

        let disabled = try await service.setEnabled(mods[0], enabled: false)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertTrue(disabled.fileName.hasSuffix(".jar.disabled"))

        mods = try await service.list(instance: inst, kind: .mod)
        XCTAssertEqual(mods.count, 1)
        XCTAssertFalse(mods[0].isEnabled)

        let enabled = try await service.setEnabled(mods[0], enabled: true)
        XCTAssertTrue(enabled.isEnabled)
    }
}

final class LanDiscoveryParsingTests: XCTestCase {
    func testExtractMotdAndPort() {
        let payload = "[MOTD]My World[/MOTD][AD]54321[/AD]"
        XCTAssertEqual(LanWorldDiscoveryServiceImpl.extract(tag: "MOTD", from: payload), "My World")
        XCTAssertEqual(LanWorldDiscoveryServiceImpl.extract(tag: "AD", from: payload), "54321")
    }
}

final class CurseForgeKeyResolverTests: XCTestCase {
    func testReadsKeyFromLocalSecrets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-cf-\(UUID().uuidString)", isDirectory: true)
        let secrets = root.appendingPathComponent(".local-secrets", isDirectory: true)
        try FileManager.default.createDirectory(at: secrets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "test-api-key\n".write(to: secrets.appendingPathComponent("curseforge.key"), atomically: true, encoding: .utf8)
        let resolver = CurseForgeApiKeyResolver(dataDirectory: root)
        XCTAssertEqual(resolver.resolve(), "test-api-key")
    }
}

final class LocalSaveServiceTests: XCTestCase {
    func testImportRequiresLevelDat() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-save-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let instance = GameInstance(
            name: "test",
            minecraftVersion: "1.20.1",
            loader: .vanilla,
            versionName: "test",
            instanceDirectory: root.path
        )
        let service = LocalSaveServiceImpl()

        let staging = root.appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data([0x0A]).write(to: staging.appendingPathComponent("level.dat"))

        let zip = root.appendingPathComponent("world.zip")
        try writeStoredZip(entries: [("level.dat", Data([0x0A]))], to: zip)

        let save = try await service.importFromZip(instance: instance, archiveURL: zip)
        XCTAssertEqual(save.name, "world")
        let listed = try await service.listSaves(instance: instance)
        XCTAssertEqual(listed.count, 1)
    }

    private func writeStoredZip(entries: [(String, Data)], to url: URL) throws {
        // Minimal stored (no compression) ZIP writer for tests.
        var data = Data()
        var central = Data()
        var offsets: [UInt32] = []
        for (name, payload) in entries {
            offsets.append(UInt32(data.count))
            let nameData = Data(name.utf8)
            data.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // local header
            data.append(contentsOf: [0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
            data.append(contentsOf: UInt32(0).littleEndianBytes)
            data.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            data.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            data.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
            data.append(contentsOf: UInt16(0).littleEndianBytes)
            data.append(nameData)
            data.append(payload)

            central.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            central.append(contentsOf: [0x14, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
            central.append(contentsOf: UInt32(0).littleEndianBytes)
            central.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            central.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            central.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes) // extra
            central.append(contentsOf: UInt16(0).littleEndianBytes) // comment
            central.append(contentsOf: UInt16(0).littleEndianBytes) // disk
            central.append(contentsOf: UInt16(0).littleEndianBytes) // int attr
            central.append(contentsOf: UInt32(0).littleEndianBytes) // ext attr
            central.append(contentsOf: offsets.last!.littleEndianBytes)
            central.append(nameData)
        }
        let centralOffset = UInt32(data.count)
        data.append(central)
        data.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        data.append(contentsOf: UInt16(0).littleEndianBytes)
        data.append(contentsOf: UInt16(0).littleEndianBytes)
        data.append(contentsOf: UInt16(entries.count).littleEndianBytes)
        data.append(contentsOf: UInt16(entries.count).littleEndianBytes)
        data.append(contentsOf: UInt32(central.count).littleEndianBytes)
        data.append(contentsOf: centralOffset.littleEndianBytes)
        data.append(contentsOf: UInt16(0).littleEndianBytes)
        try data.write(to: url)
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian) { Array($0) }
    }
}
