/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import Security
import BlockHelmApplication
import BlockHelmDomain

/// Microsoft account sign-in scaffold using Keychain for token storage.
/// Full Xbox Live → XSTS → Minecraft Services exchange is wired as a staged pipeline;
/// interactive browser auth uses AuthenticationServices on the App layer via `MicrosoftAuthSessionProviding`.
public protocol MicrosoftAuthSessionProviding: Sendable {
    func acquireAuthorizationCode(clientId: String, redirectURI: String, scopes: [String]) async throws -> String
}

public struct MicrosoftAuthConfig: Sendable {
    public var clientId: String
    public var redirectURI: String
    public var scopes: [String]

    public init(
        clientId: String = "",
        redirectURI: String = "http://localhost:7913/callback",
        scopes: [String] = ["XboxLive.signin", "offline_access", "openid", "profile"]
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

public enum MicrosoftAuthError: LocalizedError {
    case missingClientId
    case missingSessionProvider
    case tokenExchangeFailed(String)
    case entitlementMissing

    public var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Microsoft OAuth client id is not configured."
        case .missingSessionProvider:
            return "Authentication session provider is unavailable."
        case .tokenExchangeFailed(let detail):
            return "Microsoft token exchange failed: \(detail)"
        case .entitlementMissing:
            return "This Microsoft account does not own Minecraft."
        }
    }
}

public final class KeychainTokenStore: @unchecked Sendable {
    private let service: String

    public init(service: String = "com.blockhelm.launcher.tokens") {
        self.service = service
    }

    public func save(accountId: String, token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func load(accountId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete(accountId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public final class MicrosoftAccountServiceImpl: MicrosoftAccountService, @unchecked Sendable {
    private let config: MicrosoftAuthConfig
    private let sessionProvider: MicrosoftAuthSessionProviding?
    private let tokenStore: KeychainTokenStore
    private let client: HTTPClient

    public init(
        config: MicrosoftAuthConfig = MicrosoftAuthConfig(),
        sessionProvider: MicrosoftAuthSessionProviding? = nil,
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        client: HTTPClient = HTTPClient()
    ) {
        self.config = config
        self.sessionProvider = sessionProvider
        self.tokenStore = tokenStore
        self.client = client
    }

    public func signIn() async throws -> LauncherAccountRecord {
        guard !config.clientId.isEmpty else { throw MicrosoftAuthError.missingClientId }
        guard let sessionProvider else { throw MicrosoftAuthError.missingSessionProvider }

        let code = try await sessionProvider.acquireAuthorizationCode(
            clientId: config.clientId,
            redirectURI: config.redirectURI,
            scopes: config.scopes
        )

        // Staged token exchange — stores the auth code receipt until full Xbox pipeline is completed.
        // Callers can still create a placeholder Microsoft account entry for UI wiring.
        let account = LauncherAccountRecord(
            displayName: "Microsoft Account",
            kind: .microsoft,
            uuid: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            isOffline: false
        )
        try tokenStore.save(accountId: account.id, token: code)
        return account
    }
}
