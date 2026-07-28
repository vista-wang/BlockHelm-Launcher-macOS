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
