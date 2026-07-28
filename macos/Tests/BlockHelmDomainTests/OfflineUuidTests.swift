import XCTest
@testable import BlockHelmDomain

final class OfflineUuidTests: XCTestCase {
    func testStandardOfflineUuidIsDeterministic() {
        let a = OfflineUuid.standard(from: "Steve")
        let b = OfflineUuid.standard(from: "Steve")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32)
    }

    func testDifferentNamesProduceDifferentUuids() {
        XCTAssertNotEqual(OfflineUuid.standard(from: "Steve"), OfflineUuid.standard(from: "Alex"))
    }

    func testLoaderKindRawValuesMatchWindowsSchema() {
        XCTAssertEqual(LoaderKind.vanilla.rawValue, 0)
        XCTAssertEqual(LoaderKind.fabric.rawValue, 1)
        XCTAssertEqual(LoaderKind.forge.rawValue, 2)
        XCTAssertEqual(LoaderKind.neoForge.rawValue, 3)
        XCTAssertEqual(LoaderKind.quilt.rawValue, 4)
    }

    func testSettingsJSONUsesPascalCaseKeys() throws {
        let settings = LauncherSettings(theme: "Light", accentColor: "Cyan")
        let data = try JSONEncoder().encode(settings)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"Theme\""))
        XCTAssertTrue(json.contains("\"AccentColor\""))
        XCTAssertTrue(json.contains("Light"))
    }

    func testGameInstanceRoundTrip() throws {
        var instance = GameInstance(name: "Test", minecraftVersion: "1.21.1", versionName: "1.21.1")
        instance.loader = .fabric
        instance.loaderVersion = "0.16.0"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(instance)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GameInstance.self, from: data)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.loader, .fabric)
        XCTAssertEqual(decoded.loaderVersion, "0.16.0")
    }
}
