# ADR-0026: Single Package Consolidation

## Status: Proposed

## Context

Pennyfarthing currently ships as 12 npm packages:

| Package | Purpose | Native deps? |
|---------|---------|:---:|
| `@pennyfarthing/core` | CLI + agents + workflows + scripts | No |
| `@pennyfarthing/shared` | Portrait resolution, YAML helpers | No |
| `@pennyfarthing/cyclist` | Visual terminal (Electron + web server + BikeRack) | **Yes** (node-pty) |
| `@pennyfarthing/benchmark` | JobFair benchmarking | No |
| `@pennyfarthing/themes-*` (x7) | Theme packs | No |

This creates three installation pain points:

1. **BikeRack is trapped behind Cyclist.** BikeRack is a pure-JS web dashboard, but it lives inside `@pennyfarthing/cyclist`, which depends on `node-pty` (native C++ module requiring compilation toolchain). Users who just want the monitoring dashboard must compile native modules they'll never use.

2. **Multi-package install is confusing.** Users must know to install `core`, then optionally `cyclist`, then optionally themes. Each is a dropout point.

3. **node-pty is the #1 install failure.** It requires Python + C++ toolchain, fails across Node versions and platforms, and is only used by the TTY terminal panel — which is being removed.

### Key findings from architecture review

- **ClaudeService uses `child_process.spawn`**, not node-pty. Conversation works without any native modules.
- **node-pty is dynamically imported** (`await import('node-pty')`) only when the TTY panel spawns a shell. With TTY panel removal, node-pty has zero uses.
- **BikeRack's entire dependency tree is pure JavaScript**: Express, WebSocket, React 19, Dockview, Radix UI.
- **Cyclist Web mode** (`dev:web`) already runs the full experience without Electron — conversation, panels, everything — as a Node.js web server.
- **`@pennyfarthing/shared`** is 592K with one dependency (yaml, already in core). No reason to be separate.
- **`@pennyfarthing/benchmark`** is 204K with one dependency (yaml). Already peer-depends on core.

## Decision

Consolidate all packages into **one npm package** plus optional theme packs. Distribute Electron apps as **standalone downloads**, not npm packages.

### New package topology

```
@pennyfarthing/core           ONE npm package
├── CLI (init, update, doctor, uninstall)
├── Agents, workflows, guides, skills, scripts
├── Python CLI tools (pennyfarthing_scripts/)
├── Shared utilities (portrait resolution, YAML helpers)
├── Benchmark / JobFair
├── Web server (Express + WebSocket)
├── React UI (pre-built static assets)
│   ├── All monitoring panels (Sprint, Git, Diffs, Todo, etc.)
│   ├── MessagePanel (conversation view)
│   ├── Dockview layout system
│   └── BikeRack/BikeShow workspace (panel-only mode)
└── ClaudeService (child_process.spawn, stream-json)

@pennyfarthing/themes-*       Optional theme packs (unchanged)

Cyclist.app / Cyclist.exe     Standalone Electron download (NOT npm)
BikeShow.app / BikeShow.exe   Standalone Electron panel viewer (NOT npm)
```

### CLI commands

```bash
# Install
npm install --save-dev @pennyfarthing/core
npx pennyfarthing init

# Launch modes
npx pennyfarthing web         # Full Cyclist web — conversation + all panels
npx pennyfarthing bikerack    # Monitoring dashboard — panels only, no conversation

# Optional
npm install --save-dev @pennyfarthing/themes-scifi
```

### What gets absorbed into core

| Former package | Disposition |
|---------------|------------|
| `@pennyfarthing/shared` | Merged. Exports become `@pennyfarthing/core/shared` or top-level re-exports. |
| `@pennyfarthing/benchmark` | Merged. Optional feature, loaded on demand. |
| `@pennyfarthing/cyclist` (web server, React UI, APIs, WebSocket) | Merged. Pre-built React bundle shipped as static assets in `dist/public/`. |
| `@pennyfarthing/cyclist` (Electron shell, node-pty, xterm) | **Removed from npm.** Electron apps distributed as standalone downloads via GitHub releases / electron-builder. |

### Electron distribution

Cyclist and BikeShow become standalone desktop applications:

- **Cyclist.app** — Full desktop experience. Electron shell wrapping the same web server from core. Bundles node-pty for native terminal if desired.
- **BikeShow.app** — Standalone panel viewer. Electron shell running BikeRack mode. No conversation, no terminal.

Both built with electron-builder (already configured in `packages/cyclist/package.json`). Distributed via GitHub releases, not npm. A user downloads the app once; it discovers projects by scanning for `.pennyfarthing/` directories or accepting `--project-dir`.

### Dependency impact on core

Core's runtime dependencies grow from 7 to ~25:

**Current core deps (7):** chalk, commander, fs-extra, inquirer, open, yaml, @pennyfarthing/shared

**Added from Cyclist web (net ~18):** express, ws, react, react-dom, dockview-react, 12x @radix-ui/react-*, class-variance-authority, clsx, cmdk, lucide-react, tailwind-merge, electron-window-state (removed), node-pty (removed), xterm (removed), xterm-addon-fit (removed)

**All pure JavaScript. Zero native modules. Zero compilation.**

### Lazy loading strategy

The web server and React dependencies only load when a user runs `pennyfarthing web` or `pennyfarthing bikerack`. The CLI path (`init`, `update`, `doctor`) never imports Express or React. This keeps CLI operations fast despite the larger package.

```
pennyfarthing init      → imports: commander, fs-extra, yaml, chalk
pennyfarthing web       → imports: above + express, ws, react (pre-built bundle)
pennyfarthing bikerack  → imports: above + express, ws, react (pre-built bundle, no ClaudeService)
```

### Migration path

This is a **major version bump** (v11.0.0). The `pennyfarthing update` command handles migration:

1. Detect old multi-package installs (`@pennyfarthing/cyclist`, `@pennyfarthing/shared`, `@pennyfarthing/benchmark`)
2. Remove them from `package.json`
3. Ensure `@pennyfarthing/core` is at v11+
4. Re-run `pennyfarthing init` to update symlinks

### Monorepo changes

The `packages/` directory simplifies:

```
packages/
├── core/              Consolidated main package
│   ├── src/           CLI + framework
│   ├── server/        Web server (from cyclist)
│   ├── public/        React UI (from cyclist)
│   └── dist/
│       └── public/    Pre-built React bundle (Vite output)
├── electron/          Electron shell only (not published to npm)
│   ├── main.ts        Electron entry
│   ├── preload.ts
│   └── bikeshow.ts    BikeShow entry
├── themes-comedy/
├── themes-literary/
├── themes-mythology-fantasy/
├── themes-prestige-tv/
├── themes-realistic/
├── themes-scifi/
└── themes-superheroes/
```

`packages/shared/` and `packages/benchmark/` are absorbed into `packages/core/`.
`packages/cyclist/` splits: web code goes to core, Electron shell goes to `packages/electron/`.

## Consequences

### Positive

- **One install, zero native modules.** `npm install @pennyfarthing/core` gives you the full framework + web dashboard. No compilation failures.
- **BikeRack is first-class.** No longer gated behind Cyclist's dependency wall.
- **Cyclist Web is first-class.** Full conversation experience available without Electron.
- **Simpler mental model.** One package to install, optional themes for flavor, optional desktop app for power users.
- **Fewer packages to version, publish, and coordinate.** Release process simplifies from 12 packages to 1 + themes.
- **TTY panel removal eliminates the last native dependency.** node-pty and xterm are gone from the npm distribution entirely.

### Negative

- **Core package size increases.** From ~5MB to ~9MB (adding React bundle, Express, Radix UI). All are well-established, stable dependencies.
- **Major version bump.** Existing users must migrate. Mitigated by `pennyfarthing update` automation.
- **Electron apps need a distribution channel.** GitHub releases + electron-builder is the path, but it's a new publishing workflow to maintain.
- **Monorepo restructure.** Moving code between packages is a significant one-time effort.

### Neutral

- Theme packages remain unchanged — separate, optional, zero deps.
- Python CLI tools (`pennyfarthing_scripts/`) distribution is unchanged — bundled in core's `files` array.
- Agent definitions, guides, skills, workflows — unchanged, still sourced from `pennyfarthing-dist/`.
