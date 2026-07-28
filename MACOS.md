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

If the system temp disk is full, point `TMPDIR` at a volume with free space (for example the repo’s `tmp/` folder).

Or open `Package.swift` in Xcode and run the `BlockHelmApp` scheme.

> The SwiftUI app target must be built on macOS.

## MVP scope

- Shell navigation (8 pages)
- Home launch + launch integrity checks
- Download + install (Vanilla, Fabric, Quilt, Forge, NeoForge)
- Modrinth `.mrpack` import (loader install, files, overrides / client-overrides)
- Install task list
- Instance settings + local mods / resource packs / shaders enable-disable-delete
- Local worlds/saves list, zip import (`level.dat`), delete
- Offline accounts + Microsoft auth (Xbox/XSTS/Minecraft + refresh)
- Resources: Modrinth + CurseForge (mods, resource packs, shaders, worlds) with required dependency install
- LAN world discovery (UDP 4445) + copy address
- Settings (theme, language, download source, memory, Java discovery)

## CurseForge API key

CurseForge search/install needs an API key. Resolve order:

1. `~/Library/Application Support/BHL/.local-secrets/curseforge.key`
2. `./.local-secrets/curseforge.key` (current working directory)
3. Environment variable `CURSEFORGE_API_KEY`

Do not commit key files. Without a key, CurseForge search shows a configuration hint and Modrinth remains available.

## Microsoft auth

Set environment variables before signing in:

* `BLOCKHELM_MS_CLIENT_ID` — Azure / Microsoft application (client) ID
* `BLOCKHELM_MS_REDIRECT_URI` — optional; defaults to `ms-xal-{clientId}://auth`

The Xbox Live → XSTS → Minecraft Services exchange is implemented. Offline accounts remain fully usable without these variables.

## Data paths

| Item | Path |
|------|------|
| Launcher data | `~/Library/Application Support/BHL/` |
| Settings | `…/BHL/settings.json` |
| Accounts | `…/BHL/accounts/account-state.json` |
| Minecraft | `…/BHL/.minecraft/` |
| CurseForge key | `…/BHL/.local-secrets/curseforge.key` |

JSON property names stay **PascalCase** for compatibility with the Windows schemas.

## Intentionally deferred / platform gaps

| Capability | Status on macOS |
|------------|-----------------|
| Terracotta / Windows-only remote play | Unavailable (documented in Multiplayer page) |
| CurseForge modpack (`.zip` manifest) import | Deferred; use Modrinth `.mrpack` |
| Skin / cape editor, full account skin sync | Deferred |
| In-game process log console parity | Partial (launch logs under `BHL/logs`) |
| Windows WPF animations / theme chrome | Native SwiftUI presentation instead |

Keep extending toward Windows feature parity on `port-macos` without restoring deleted experimental trees.
