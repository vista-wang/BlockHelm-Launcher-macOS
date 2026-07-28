/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import AppKit
import AuthenticationServices
import BlockHelmApplication
import BlockHelmDomain
import BlockHelmInfrastructure

@MainActor
public final class AppContainer: ObservableObject {
    public let pathProvider: MacLauncherPathProvider
    public let settingsService: SettingsService
    public let accountStore: AccountStore
    public let instanceRepository: GameInstanceRepository
    public let instanceService: GameInstanceService
    public let versionService: GameVersionService
    public let installService: GameInstallService
    public let launchService: LaunchService
    public let javaDiscovery: JavaRuntimeDiscoveryService
    public let offlineAccounts: OfflineAccountService
    public let microsoftAccounts: MicrosoftAccountService
    public let installTasks: InMemoryInstallTaskQueue
    public let httpClient: HTTPClient

    public init() {
        let paths = MacLauncherPathProvider()
        let client = HTTPClient()
        let settings = JSONSettingsService(pathProvider: paths)
        let accounts = JSONAccountStore(pathProvider: paths)
        let instances = JSONGameInstanceRepository(pathProvider: paths)
        let instanceService = DefaultGameInstanceService(
            repository: instances,
            pathProvider: paths,
            settingsService: settings
        )
        let java = MacJavaRuntimeDiscoveryService()
        let authSession = ASWebMicrosoftAuthSessionProvider()

        self.pathProvider = paths
        self.httpClient = client
        self.settingsService = settings
        self.accountStore = accounts
        self.instanceRepository = instances
        self.instanceService = instanceService
        self.versionService = MojangGameVersionService(client: client, pathProvider: paths)
        self.installService = MinecraftInstallService(
            client: client,
            pathProvider: paths,
            instanceService: instanceService
        )
        self.launchService = MinecraftLaunchService(pathProvider: paths, javaDiscovery: java)
        self.javaDiscovery = java
        self.offlineAccounts = DefaultOfflineAccountService()
        self.microsoftAccounts = MicrosoftAccountServiceImpl(
            config: MicrosoftAuthConfig(
                clientId: ProcessInfo.processInfo.environment["BLOCKHELM_MS_CLIENT_ID"] ?? ""
            ),
            sessionProvider: authSession
        )
        self.installTasks = InMemoryInstallTaskQueue()
    }
}

/// Bridges AuthenticationServices into Infrastructure's auth session protocol.
final class ASWebMicrosoftAuthSessionProvider: NSObject, MicrosoftAuthSessionProviding, ASWebAuthenticationPresentationContextProviding {
    func acquireAuthorizationCode(clientId: String, redirectURI: String, scopes: [String]) async throws -> String {
        let scope = scopes.joined(separator: " ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let redirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        let urlString = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(redirect)&scope=\(scope)&response_mode=query"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let callbackScheme = URL(string: redirectURI)?.scheme ?? "http"

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: URLError(.userAuthenticationRequired))
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: URLError(.cannotStartLoad))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
