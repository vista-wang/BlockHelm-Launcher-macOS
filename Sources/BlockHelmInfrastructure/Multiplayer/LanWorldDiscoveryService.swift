/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import Network
import BlockHelmApplication
import BlockHelmDomain

/// Discovers Minecraft worlds opened to LAN via UDP port 4445 advertisements.
public actor LanWorldDiscoveryServiceImpl: LanWorldDiscoveryService {
    private var listener: NWListener?
    private var worlds: [String: LanWorldAdvertisement] = [:]
    private var pruneTask: Task<Void, Never>?

    public init() {}

    public func start() async {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: 4445)
            listener.newConnectionHandler = { [weak self] connection in
                Task { await self?.handle(connection: connection) }
            }
            listener.stateUpdateHandler = { state in
                if case .failed = state {
                    // Keep running; caller can restart.
                }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
            pruneTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    self.pruneStale()
                }
            }
        } catch {
            // Port may be in use; discovery remains empty.
        }
    }

    public func stop() async {
        pruneTask?.cancel()
        pruneTask = nil
        listener?.cancel()
        listener = nil
        worlds.removeAll()
    }

    public func snapshot() async -> [LanWorldAdvertisement] {
        pruneStale()
        return worlds.values.sorted { $0.discoveredAt > $1.discoveredAt }
    }

    private func pruneStale() {
        let cutoff = Date().addingTimeInterval(-30)
        worlds = worlds.filter { $0.value.discoveredAt >= cutoff }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receiveMessage { [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            guard let motd = Self.extract(tag: "MOTD", from: text),
                  let portText = Self.extract(tag: "AD", from: text),
                  let port = Int(portText)
            else { return }
            let host: String
            if let endpoint = connection.currentPath?.remoteEndpoint,
               case .hostPort(let nwHost, _) = endpoint {
                host = "\(nwHost)"
            } else {
                host = "127.0.0.1"
            }
            let ad = LanWorldAdvertisement(motd: motd, address: host, port: port)
            Task { await self?.upsert(ad) }
        }
    }

    private func upsert(_ ad: LanWorldAdvertisement) {
        worlds[ad.id] = ad
    }

    static func extract(tag: String, from text: String) -> String? {
        let open = "[\(tag)]"
        let close = "[/\(tag)]"
        guard let start = text.range(of: open),
              let end = text.range(of: close, range: start.upperBound..<text.endIndex)
        else { return nil }
        return String(text[start.upperBound..<end.lowerBound])
    }
}
