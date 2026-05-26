# Story 98-21: Standalone Electron distribution via GitHub releases

**Jira:** PROJ-15079
**Epic:** epic-98 (Safe Install, Upgrade, and Namespace Isolation)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/98-21-standalone-electron-distribution
**Assigned:** slabgorb@gmail.com

---

## Description

Build automated GitHub releases distribution for the Electron app (Cyclist). Story 98-20 extracted the Electron shell into `packages/electron/` with electron-builder configured. This story completes the release pipeline: generate signed DMG/installer binaries via GitHub Actions, publish to GitHub Releases, and provide installation/upgrade instructions for end users.

**Prerequisites:** Story 98-20 complete (Electron package extracted, electron-builder config ready).

## Acceptance Criteria

- [x] GitHub Actions workflow file (`.github/workflows/release-electron.yml`) triggers on version tag (`v*`) or manual dispatch
- [x] Workflow builds macOS DMG and zip artifacts using electron-builder (matrix: `macos-latest`)
- [x] Workflow builds Windows NSIS installer and portable exe (matrix: `windows-latest`)
- [x] Workflow builds Linux AppImage and deb packages (matrix: `ubuntu-latest`)
- [x] Built artifacts uploaded to GitHub Releases (draft or published, configurable via `inputs.draft`)
- [x] Release notes auto-generated from commit history (git log between tags)
- [x] Code signing configured for macOS — env vars `CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`, notarization; Windows via `WIN_CSC_LINK` (stubs — needs certs in secrets)
- [x] Installation documentation added: `packages/electron/DISTRIBUTION.md` with download table, platform instructions, upgrade paths, troubleshooting
- [x] CI workflow integrated into monorepo pnpm workspace (`pnpm install` + `pnpm run build` builds all deps in order)
- [x] Tests run as gate job before build (shared, core, cyclist suites + electron tsc check)

## Technical Approach

**File Structure (packages/electron/):**
- `package.json` — electron-builder config already present (mac, win, linux targets)
- `src/main.ts`, `src/preload.ts` — Electron entry points (from 98-20)
- `tsconfig.json`, `tsconfig.preload.json` — TypeScript configs
- `build/` — icon.icns (and future build resources)

**GitHub Actions Setup:**
- Workflow triggered on: git tag matching `v*` or manual workflow dispatch
- Build steps:
  1. Install pnpm deps (monorepo)
  2. Build packages/shared, packages/core, packages/cyclist (workspace deps)
  3. Run `npm run build:electron` in packages/electron (tsc + electron-builder)
  4. Upload artifacts to GitHub Release
  5. Auto-generate release notes from commits

**Code Signing (macOS):**
- electron-builder supports Apple certificates via environment variables (`CSC_LINK`, `CSC_KEY_PASSWORD`)
- Notarization: `electron-notarize` plugin (stub with TODO for credential setup)
- Windows: SignTool.exe path configuration (stub if no cert available)

**Installation Docs:**
- `packages/electron/DISTRIBUTION.md` — quick-start, download links, upgrade instructions, troubleshooting
- Reference in main README

**CI Integration:**
- Monorepo pnpm commands: `pnpm install`, `pnpm run build` (builds all packages in dependency order)
- Cyclist and Electron e2e tests run pre-release to validate distribution integrity

## Key Files

- `packages/electron/package.json` — electron-builder config (mac, win, linux targets)
- `packages/electron/src/main.ts` — Electron main process
- `packages/electron/src/preload.ts` — Preload script
- `packages/electron/tsconfig.json`, `tsconfig.preload.json` — TypeScript configs
- `packages/electron/build/icon.icns` — macOS app icon
- `.github/workflows/release.yml` — GitHub Actions release workflow (TO CREATE)
- `packages/electron/DISTRIBUTION.md` — Installation/upgrade guide (TO CREATE)
- `pnpm-workspace.yaml` — monorepo configuration (already exists)

## Architecture Notes

**Electron Package Dependencies (from story 98-20):**
- Depends on `@pennyfarthing/core` (workspace) — WheelHub server, API routes
- Depends on `@pennyfarthing/cyclist` (workspace) — React UI, server bridge

**Release Targets:**
- **macOS:** DMG + Zip (asar bundle, codesign optional, notarize optional)
- **Windows:** NSIS installer + Portable EXE
- **Linux:** AppImage + deb package

**Version Coordination:**
- All packages use same version (11.1.1) via pnpm workspaces
- Git tag format: `v11.1.1` triggers release workflow
- Release notes sourced from commit messages (conventional commits style)

**Known Gaps (from 98-20):**
- No GitHub Actions workflow yet
- No code signing certificates configured (stub with TODO for setup)
- No installation documentation
- CI environment may need special handling for electron-builder (cross-compilation, ASAR packing)

---

## TEA Assessment

**Tests Required:** No
**Reason:** Chore bypass — story deliverables are entirely CI/CD configuration (GitHub Actions YAML) and documentation (DISTRIBUTION.md). No application code is being written or modified. electron-builder config already exists from 98-20. The workflow YAML is validated by GitHub Actions itself; code signing is stub configuration. Writing file-existence or YAML-structure assertions would be testing the testing framework, not the feature.

**Bypass Criteria Met:**
- Configuration changes (CI, build config) — primary deliverable is `.github/workflows/release.yml`
- Documentation updates — `packages/electron/DISTRIBUTION.md`

**Existing CI Patterns to Follow:**
- `ci.yml`: self-hosted Ubuntu runners, pnpm v9, Node 20, pnpm cache
- `publish.yml`: workflow_dispatch with inputs, release trigger, dry-run support
- electron-builder targets already configured in `packages/electron/package.json`

**Implementation Notes for Dev:**
- Use matrix strategy for multi-platform builds (macOS, Windows, Linux need different runners)
- Self-hosted runners are `[self-hosted, Ubuntu, Common]` — may need macOS/Windows runners for native builds, or use GitHub-hosted runners for those platforms
- Follow existing `publish.yml` pattern for secrets and permissions
- AC 10 (tests pass in CI) is a meta-AC — ensure the release workflow runs existing test suite before building

**Handoff:** To Dev for implementation (no tests to write)

## DevOps Assessment (Miracle Max)

**Files Created:**
- `.github/workflows/release-electron.yml` — Multi-platform release pipeline
- `packages/electron/DISTRIBUTION.md` — Installation and upgrade documentation

**Design Decisions:**
1. **GitHub-hosted runners** for release builds (macOS, Windows, Linux) — more reliable than self-hosted for cross-platform, avoids needing macOS/Windows self-hosted runners
2. **Self-hosted Ubuntu for test gate** — faster, uses existing CI infrastructure
3. **`softprops/action-gh-release@v2`** for release creation — well-maintained, handles artifact upload and release notes
4. **Concurrency group** prevents parallel releases from conflicting
5. **Code signing via secrets** (optional) — builds work unsigned when certs aren't configured, with `CSC_IDENTITY_AUTO_DISCOVERY=false` fallback
6. **`skip_tests` input** for re-runs after fixing test issues without re-running the full suite
7. **Draft release** option for manual dispatch — allows review before publishing

**AC Coverage:** All 10 acceptance criteria addressed. See checked items above.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [MEDIUM] | Script injection via `${{ inputs.tag }}` in bash — should use env var | `release-electron.yml:178-179` |
| [LOW] | No `timeout-minutes` on build jobs — electron-builder can hang | `release-electron.yml:75-159` |
| [VERIFIED] | Build matrix covers all 3 platforms with fail-fast: false | `release-electron.yml:78-90` |
| [VERIFIED] | Code signing graceful fallback via CSC_IDENTITY_AUTO_DISCOVERY | `release-electron.yml:141` |
| [VERIFIED] | Concurrency group prevents parallel release conflicts | `release-electron.yml:27-29` |
| [VERIFIED] | pnpm workspace integration correct — builds all deps in order | `release-electron.yml:119-123` |
| [VERIFIED] | Artifact upload/download/release wiring correct | `release-electron.yml:145-250` |
| [VERIFIED] | No hardcoded secrets — all via ${{ secrets.* }} | both files |
| [VERIFIED] | DISTRIBUTION.md accurate — matches main.ts, correct relative links | `DISTRIBUTION.md` |

**Data flow traced:** Tag push → version determination → pnpm build → electron-builder → artifact upload → GitHub Release creation. Safe — no user input reaches code execution paths except the MEDIUM script injection noted above (self-injectable only).

**Handoff:** To SM for finish-story

## Session Log

- **TEA (Fezzik):** Assessed story — chore bypass. Pure CI config + docs, no testable application code. Handing off to Dev.
- **DevOps (Miracle Max):** Implemented release workflow and distribution docs. All ACs addressed. Committed to feature branch.
- **Reviewer (Westley):** APPROVED — no Critical/High issues. 1 MEDIUM (script injection, self-injectable only), 1 LOW (no timeout). All 9 verifications passed.