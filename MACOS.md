# BlockHelm for macOS

SwiftUI port of BlockHelm Launcher. Requires **macOS 13+** and **Xcode 15+**.

The Windows `.NET` / WPF tree (`Launcher.*`, `Launcher.sln`) remains at the repository root as the behavioral reference. Do not delete it until macOS feature parity is reached.

## Layout

```text
Package.swift
Sources/
  BlockHelmDomain/           Domain models (mirrors Launcher.Domain)
  BlockHelmApplication/      Service protocols + orchestration
  BlockHelmInfrastructure/   URLSession, Keychain, JSON, install/launch
  BlockHelmApp/              SwiftUI shell + MVP pages
Tests/
```

Dependency direction matches the Windows solution:

`BlockHelmApp → Application/Domain/Infrastructure(composition)`  
`Infrastructure → Application/Domain`  
`Application → Domain`

## Build & run

From the repository root:

```bash
swift build
swift test
swift run BlockHelmApp
```

Or open `Package.swift` in Xcode and run the `BlockHelmApp` scheme.

> The SwiftUI app target must be built on macOS.

## MVP scope

- Shell navigation (8 pages; Resources / Multiplayer are placeholders)
- Home launch
- Download + install (Vanilla, Fabric, Quilt, Forge, NeoForge)
- Install task list
- Instance settings + local mod enable/disable/delete
- Offline accounts + Microsoft auth (Xbox/XSTS/Minecraft + refresh)
- Modrinth mod search and install into instance `mods/`
- Settings (theme, language, download source, memory, Java discovery)

## Data paths

| Item | Path |
|------|------|
| Launcher data | `~/Library/Application Support/BHL/` |
| Settings | `…/BHL/settings.json` |
| Accounts | `…/BHL/accounts/account-state.json` |
| Minecraft | `…/BHL/.minecraft/` |

JSON property names stay **PascalCase** for compatibility with the Windows schemas.

## Microsoft auth

Set environment variables before signing in:

* `BLOCKHELM_MS_CLIENT_ID` — Azure / Microsoft application (client) ID
* `BLOCKHELM_MS_REDIRECT_URI` — optional; defaults to `ms-xal-{clientId}://auth`

The Xbox Live → XSTS → Minecraft Services exchange is implemented. Offline accounts remain fully usable without these variables.
