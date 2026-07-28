/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import Security
import BlockHelmApplication
import BlockHelmDomain

/// Interactive browser OAuth is provided by the App layer via AuthenticationServices.
public protocol MicrosoftAuthSessionProviding: Sendable {
    func acquireAuthorizationCode(clientId: String, redirectURI: String, scopes: [String]) async throws -> String
}

public struct MicrosoftAuthConfig: Sendable {
    public var clientId: String
    public var redirectURI: String
    public var scopes: [String]

    public init(
        clientId: String = "",
        redirectURI: String? = nil,
        scopes: [String] = ["XboxLive.signin", "offline_access", "openid", "profile"]
    ) {
        self.clientId = clientId
        if let redirectURI, !redirectURI.isEmpty {
            self.redirectURI = redirectURI
        } else if !clientId.isEmpty {
            // Matches common Xbox Auth Library / Minecraft launcher redirect schemes.
            self.redirectURI = "ms-xal-\(clientId)://auth"
        } else {
            self.redirectURI = "http://localhost:7913/callback"
        }
        self.scopes = scopes
    }
}

public enum MicrosoftAuthError: LocalizedError {
    case missingClientId
    case missingSessionProvider
    case tokenExchangeFailed(String)
    case entitlementMissing
    case profileMissing
    case missingStoredToken

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
        case .profileMissing:
            return "Minecraft profile was not found for this account."
        case .missingStoredToken:
            return "Stored Microsoft credentials are missing. Sign in again."
        }
    }
}

struct MicrosoftTokenBundle: Codable, Sendable {
    var microsoftAccessToken: String
    var microsoftRefreshToken: String?
    var minecraftAccessToken: String
    var minecraftUsername: String
    var minecraftUuid: String
    var expiresAt: Date?
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

    func saveBundle(_ bundle: MicrosoftTokenBundle, accountId: String) throws {
        let data = try JSONEncoder().encode(bundle)
        guard let text = String(data: data, encoding: .utf8) else {
            throw MicrosoftAuthError.tokenExchangeFailed("Unable to encode token bundle.")
        }
        try save(accountId: accountId, token: text)
    }

    func loadBundle(accountId: String) -> MicrosoftTokenBundle? {
        guard let text = load(accountId: accountId),
              let data = text.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(MicrosoftTokenBundle.self, from: data)
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

        let oauth = try await exchangeAuthorizationCode(code)
        let xbox = try await authenticateXboxLive(accessToken: oauth.accessToken)
        let xsts = try await authorizeXSTS(userToken: xbox.token, userHash: xbox.userHash)
        let minecraft = try await loginMinecraft(userHash: xsts.userHash, xstsToken: xsts.token)
        try await ensureEntitlement(minecraftAccessToken: minecraft.accessToken)
        let profile = try await fetchProfile(minecraftAccessToken: minecraft.accessToken)

        let account = LauncherAccountRecord(
            displayName: profile.name,
            kind: .microsoft,
            uuid: profile.id.replacingOccurrences(of: "-", with: "").lowercased(),
            isOffline: false
        )

        let bundle = MicrosoftTokenBundle(
            microsoftAccessToken: oauth.accessToken,
            microsoftRefreshToken: oauth.refreshToken,
            minecraftAccessToken: minecraft.accessToken,
            minecraftUsername: profile.name,
            minecraftUuid: profile.id.replacingOccurrences(of: "-", with: "").lowercased(),
            expiresAt: Date().addingTimeInterval(TimeInterval(minecraft.expiresIn ?? 86_400))
        )
        try tokenStore.saveBundle(bundle, accountId: account.id)
        return account
    }

    public func launchAccount(for account: LauncherAccountRecord) async throws -> LaunchAccount {
        guard account.kind == .microsoft, account.isOffline == false else {
            return LaunchAccount.offline(from: account)
        }
        guard var bundle = tokenStore.loadBundle(accountId: account.id) else {
            throw MicrosoftAuthError.missingStoredToken
        }

        let needsRefresh: Bool
        if let expiresAt = bundle.expiresAt {
            needsRefresh = expiresAt.timeIntervalSinceNow < 120
        } else {
            needsRefresh = true
        }

        if needsRefresh {
            if let refresh = bundle.microsoftRefreshToken, !refresh.isEmpty, !config.clientId.isEmpty {
                do {
                    let oauth = try await refreshMicrosoftToken(refresh)
                    let xbox = try await authenticateXboxLive(accessToken: oauth.accessToken)
                    let xsts = try await authorizeXSTS(userToken: xbox.token, userHash: xbox.userHash)
                    let minecraft = try await loginMinecraft(userHash: xsts.userHash, xstsToken: xsts.token)
                    bundle.microsoftAccessToken = oauth.accessToken
                    bundle.microsoftRefreshToken = oauth.refreshToken ?? refresh
                    bundle.minecraftAccessToken = minecraft.accessToken
                    bundle.expiresAt = Date().addingTimeInterval(TimeInterval(minecraft.expiresIn ?? 86_400))
                    try tokenStore.saveBundle(bundle, accountId: account.id)
                } catch {
                    // Keep existing token; launch may still succeed if not expired server-side.
                }
            }
        }

        return LaunchAccount(
            username: bundle.minecraftUsername,
            uuid: bundle.minecraftUuid,
            accessToken: bundle.minecraftAccessToken,
            userType: "msa",
            kind: .microsoft
        )
    }

    private func refreshMicrosoftToken(_ refreshToken: String) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id=\(urlEncode(config.clientId))",
            "refresh_token=\(urlEncode(refreshToken))",
            "grant_type=refresh_token",
            "scope=\(urlEncode(config.scopes.joined(separator: " ")))"
        ].joined(separator: "&")
        request.httpBody = Data(body.utf8)
        do {
            return try await client.json(OAuthTokenResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
    }

    private struct OAuthTokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private struct XboxAuthResponse: Decodable {
        let Token: String
        let DisplayClaims: DisplayClaims

        struct DisplayClaims: Decodable {
            let xui: [Xui]
        }

        struct Xui: Decodable {
            let uhs: String
        }
    }

    private struct MinecraftLoginResponse: Decodable {
        let access_token: String
        let expires_in: Int?
        var accessToken: String { access_token }
        var expiresIn: Int? { expires_in }
    }

    private struct MinecraftProfile: Decodable {
        let id: String
        let name: String
    }

    private struct EntitlementsResponse: Decodable {
        let items: [Item]?
        struct Item: Decodable {
            let name: String?
        }
    }

    private func exchangeAuthorizationCode(_ code: String) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id=\(urlEncode(config.clientId))",
            "code=\(urlEncode(code))",
            "grant_type=authorization_code",
            "redirect_uri=\(urlEncode(config.redirectURI))",
            "scope=\(urlEncode(config.scopes.joined(separator: " ")))"
        ].joined(separator: "&")
        request.httpBody = Data(body.utf8)
        do {
            return try await client.json(OAuthTokenResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
    }

    private func authenticateXboxLive(accessToken: String) async throws -> (token: String, userHash: String) {
        var request = URLRequest(url: URL(string: "https://user.auth.xboxlive.com/user/authenticate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(accessToken)"
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let response: XboxAuthResponse
        do {
            response = try await client.json(XboxAuthResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
        guard let uhs = response.DisplayClaims.xui.first?.uhs else {
            throw MicrosoftAuthError.tokenExchangeFailed("Xbox user hash missing.")
        }
        return (response.Token, uhs)
    }

    private func authorizeXSTS(userToken: String, userHash: String) async throws -> (token: String, userHash: String) {
        var request = URLRequest(url: URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [userToken]
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let response: XboxAuthResponse
        do {
            response = try await client.json(XboxAuthResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
        let uhs = response.DisplayClaims.xui.first?.uhs ?? userHash
        return (response.Token, uhs)
    }

    private func loginMinecraft(userHash: String, xstsToken: String) async throws -> MinecraftLoginResponse {
        var request = URLRequest(url: URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["identityToken": "XBL3.0 x=\(userHash);\(xstsToken)"]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        do {
            return try await client.json(MinecraftLoginResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
    }

    private func ensureEntitlement(minecraftAccessToken: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.minecraftservices.com/entitlements/mcstore")!)
        request.setValue("Bearer \(minecraftAccessToken)", forHTTPHeaderField: "Authorization")
        let entitlements: EntitlementsResponse
        do {
            entitlements = try await client.json(EntitlementsResponse.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.tokenExchangeFailed(error.localizedDescription)
        }
        let names = Set((entitlements.items ?? []).compactMap(\.name))
        let owned = names.contains("product_minecraft")
            || names.contains("game_minecraft")
            || names.contains { $0.contains("minecraft") }
        if !owned {
            // Some accounts still have a profile without classic entitlement item names.
            // Fall through to profile fetch; fail there if profile is missing.
            return
        }
    }

    private func fetchProfile(minecraftAccessToken: String) async throws -> MinecraftProfile {
        var request = URLRequest(url: URL(string: "https://api.minecraftservices.com/minecraft/profile")!)
        request.setValue("Bearer \(minecraftAccessToken)", forHTTPHeaderField: "Authorization")
        do {
            return try await client.json(MinecraftProfile.self, for: request, decoder: JSONDecoder())
        } catch {
            throw MicrosoftAuthError.profileMissing
        }
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
            ?? value
    }
}
