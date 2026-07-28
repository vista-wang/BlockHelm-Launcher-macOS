import XCTest
@testable import BlockHelmInfrastructure
@testable import BlockHelmDomain

final class PathProviderTests: XCTestCase {
    func testDefaultPathsLiveUnderApplicationSupportBHL() {
        let provider = MacLauncherPathProvider()
        XCTAssertTrue(provider.dataDirectory.path.contains("Application Support/BHL")
            || provider.dataDirectory.path.contains("BHL"))
        XCTAssertEqual(provider.settingsFileURL.lastPathComponent, "settings.json")
        XCTAssertEqual(provider.accountStateFileURL.lastPathComponent, "account-state.json")
        let instanceURL = provider.instanceSettingsURL(versionName: "1.21.1")
        XCTAssertTrue(instanceURL.path.contains("/versions/1.21.1/BHL/instance-settings.json"))
    }

    func testMavenCoordinatePath() {
        XCTAssertEqual(
            MavenCoordinate.path(from: "com.mojang:logging:1.1.1"),
            "com/mojang/logging/1.1.1/logging-1.1.1.jar"
        )
        XCTAssertEqual(
            MavenCoordinate.path(from: "org.lwjgl:lwjgl:3.3.3", classifier: "natives-macos-arm64"),
            "org/lwjgl/lwjgl/3.3.3/lwjgl-3.3.3-natives-macos-arm64.jar"
        )
    }

    func testDownloadSourcePreferenceRawValues() {
        XCTAssertEqual(DownloadSourcePreference.official.rawValue, 1)
        XCTAssertEqual(DownloadSourcePreference.bmclApi.rawValue, 2)
    }
}
