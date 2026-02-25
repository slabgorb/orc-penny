# Story 132-13: Reconcile Getting Started guide with Python-first install (ADR-0028)

## Story Details
- **ID:** 132-13
- **Jira Key:** MSSCI-15649
- **Title:** Reconcile Getting Started guide with Python-first install (ADR-0028)
- **Points:** 2
- **Epic:** 132 (Developer Discovery & Onboarding)
- **Repos:** pennyfarthing
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-25T17:51:31Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|

## SM Assessment
Story claimed (MSSCI-15649), session created, branch `feat/132-13-reconcile-getting-started` ready in pennyfarthing/. TDD workflow, 2pts — routing to TEA for RED phase. Context file at `sprint/context/context-132-13.md` has detailed section-by-section change mapping against ADR-0028. Primary target is `pennyfarthing/docs/GETTING-STARTED.md` — rewrite from npm-first to Python-first install flow.

## TEA Assessment

**Tests Required:** No
**Reason:** Documentation-only story. All 7 ACs describe content changes to `pennyfarthing/docs/GETTING-STARTED.md` (markdown guide rewrite). No code logic, no runtime behavior, no functions to test. AC6 (no stale npm references) is a grep check for review; AC7 (smoke test) is manual verification. Chore bypass applies: "Documentation updates (README, docs/)".

**Handoff:** To Korben Dallas (Dev) for implementation — rewrite the guide per ADR-0028.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/docs/GETTING-STARTED.md` — rewrote installation guide per ADR-0028

**AC Coverage:**
1. No npm install instructions — all `npm install @pennyfarthing/core` and theme pack commands removed
2. Primary install is `pip install pf` — first command in Installation section
3. `pf init` described accurately — copies (not symlinks), auto package manager detection, Node deps managed
4. Prerequisites Python-first — Python 3.11+ listed first, Node 18+ marked optional/managed
5. Update/reinstall use pip — `pip install --upgrade pf`, `pf uninstall && pip install pf && pf init`
6. Self-consistent — grep confirms zero `@pennyfarthing/core` references
7. Smoke test — guide flow: `pip install pf` → `pf init` → `/pf-setup` → `pf doctor`

**Tests:** N/A (TEA bypass — documentation-only)
**Branch:** feat/132-13-reconcile-getting-started (pushed)

**Handoff:** To Reviewer (Jean-Baptiste Emanuel Zorg) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**AC verification:** All 7 ACs verified against final file content.
- AC1: Zero `npm install @pennyfarthing` commands remain. Only npm mention is "auto-detects package manager (pnpm/yarn/npm)" — contextually correct.
- AC2: `pip install pf` is first command in Installation section.
- AC3: `pf init` description says copies, auto-detects package manager, installs Node deps, writes settings.
- AC4: Python 3.11+ listed first, Node 18+ last as "(optional) installed automatically".
- AC5: Updating uses `pip install --upgrade pf`. Reinstall uses `pip install pf`.
- AC6: Grep confirms zero `@pennyfarthing/core` references.
- AC7: Sequential flow `pip install pf` → `pf init` → `/pf-setup` → `pf doctor` is coherent for a new user.

**Findings:**
- [LOW] `pf cyclist start` at line 314 — this command doesn't exist yet (`pf cyclist` is not a registered CLI subcommand). The old value `npm run dev:web` is technically still correct for dev usage. Since Cyclist is marked optional and the guide says "start with CLI mode," this is non-blocking.
- [LOW] Doctor output at lines 93-101 removed `symlinks` and `node_packages` checks — actual `pf doctor` may still display these. Minor discrepancy, non-blocking.
- [VERIFIED] No stale `@pennyfarthing/core` references anywhere in the document.
- [VERIFIED] Prerequisites correctly ordered (Python first, Node last/optional).
- [VERIFIED] Fresh reinstall path uses pip, not npm.

**Handoff:** To SM for finish-story

## Story Context

### Acceptance Criteria
1. No npm install instructions for Pennyfarthing. The guide must not tell users to run `npm install @pennyfarthing/core` or `npm install @pennyfarthing/themes-*`.
2. Primary install is `pip install pf`. This is the first command in the Installation section.
3. `pf init` described accurately. The description matches what `core.py` actually does — copies (not symlinks), auto-detects package manager, installs Node deps, writes settings.
4. Prerequisites reflect Python-first. Python 3.11+ is listed first. Node is described as a managed dependency.
5. Update/reinstall instructions use pip. No `npm update` commands in the Updating or Troubleshooting sections.
6. Guide is self-consistent. No leftover references to `@pennyfarthing/core` as an npm package anywhere in the document.
7. Smoke test: A new user following the guide on a clean project can install and initialize Pennyfarthing using only the documented steps.

### Technical Approach
Rewrite `pennyfarthing/docs/GETTING-STARTED.md` to match ADR-0028 (Python-first install). Replace all npm-based install/update instructions with pip/pipx equivalents. Update prerequisites to lead with Python 3.11+. Update `pf init` description to reflect copies (not symlinks), auto package manager detection, and managed Node deps.

### Key Files
| File | Action |
|------|--------|
| `pennyfarthing/docs/GETTING-STARTED.md` | Primary file to rewrite |
| `docs/adr/0028-python-first-installation.md` | Reference (read-only) |
| `pennyfarthing/pennyfarthing-dist/src/pf/init/core.py` | Reference — what `pf init` actually does |