# Story 126-11: Update stale pennyfarthing init references to pf setup

## Story Details
- **ID:** 126-11
- **Jira:** MSSCI-15599
- **Workflow:** trivial
- **Points:** 2
- **Priority:** p1
- **Assigned:** keith.avery@1898andco.io

## Story Description
~30 string references to pennyfarthing init and npx pennyfarthing remain after init.ts removal in 126-9. Users hitting these error paths are told to run a command that no longer exists. ACs: All pennyfarthing init refs updated to pf setup. All npx pennyfarthing refs updated to pf. No user-facing message references a nonexistent command.

## Acceptance Criteria
- [ ] All pennyfarthing init refs updated to pf setup
- [ ] All npx pennyfarthing refs updated to pf
- [ ] No user-facing message references a nonexistent command

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/skill.ts` - 5x `pennyfarthing init` → `pf setup`, 2x `pennyfarthing update` → `pf setup`
- `packages/core/src/cli/commands/command.ts` - 5x `pennyfarthing init` → `pf setup`, 2x `pennyfarthing update` → `pf setup`
- `packages/core/src/cli/commands/theme.ts` - 3x `pennyfarthing init` → `pf setup`
- `packages/core/src/cli/commands/version.ts` - 1x `pennyfarthing init` → `pf setup`
- `packages/core/src/cli/commands/doctor.ts` - 1x `pennyfarthing init` → `pf setup`
- `packages/core/src/cli/commands/uninstall.ts` - 1x `pennyfarthing init` → `pf setup`
- `packages/core/src/cli/utils/files.ts` - 1x comment updated
- `packages/core/src/cli/commands/cyclist.test.ts` - 1x `npx pennyfarthing` → `pf`
- `packages/cyclist/src/pennyfarthing.ts` - 2x comments updated
- `packages/cyclist/scripts/install-cli.sh` - 1x `npx pennyfarthing init` → `pf setup`
- `packages/cyclist/README.md` - refs updated
- `pennyfarthing-dist/commands/pf-help.md` - 1x `npx pennyfarthing init` → `pf setup`
- `pennyfarthing-dist/commands/pf-setup.md` - 3x refs + 1x `pennyfarthing doctor` → `pf doctor`
- `pennyfarthing-dist/guides/hooks.md` - 1x `pennyfarthing init` → `pf setup`
- `pennyfarthing-dist/templates/justfile.template` - 1x comment
- `pennyfarthing-dist/templates/pyproject.toml` - 1x comment
- `pennyfarthing-dist/src/pf/git/hooks_installer.py` - 1x error message
- `pennyfarthing-dist/scripts/hooks/{pre-commit,post-merge,pre-push}.sh` - comments
- `pennyfarthing-dist/scripts/tests/test-post-merge-hook.sh` - 2x refs
- `pennyfarthing-dist/scripts/misc/uninstall.sh` - 1x reinstall message
- `pennyfarthing-dist/workflows/installation-check/steps/step-01-foundation.md` - 2x
- `pennyfarthing-dist/workflows/installation-check/steps/step-05-layout.md` - 1x
- `README.md` - CLI table and quickstart
- `install-handoff.md` - multiple npx refs
- `docs/{GETTING-STARTED,USER-GUIDE,README,TROUBLESHOOTING,DEBUGGING-SESSIONS,CI-CD-INTEGRATION,ARCHITECTURE,COMMANDS,PERMISSIONS,PERSONAS}.md` - all npx/init refs
- `docs/adr/0005-single-source-of-truth-symlinks.md` - 1x
- `docs/archive/HANDOFF-script-paths.md` - 2x
- `tests/integration/test_consumer_install.sh` - 2x

**Intentionally preserved:**
- `CHANGELOG.md` — historical records
- `pennyfarthing-dist/src/pf/upgrade/core.py` — detects old `npx pennyfarthing` hooks
- `tests/python/test_upgrade_npm_to_python.py` — tests old command detection

**Tests:** N/A (string replacements only, no logic changes)
**Branch:** feat/126-11-update-stale-init-refs (pushed)

**AC Coverage:**
- [x] All pennyfarthing init refs updated to pf setup — 40 files, ~70 replacements
- [x] All npx pennyfarthing refs updated to pf — all user-facing npx refs replaced
- [x] No user-facing message references a nonexistent command — verified via grep

**Handoff:** To review phase

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [VERIFIED] | All 40 files contain only string replacements — no logic, no control flow, no structural changes | diff review |
| 2 | [VERIFIED] | CHANGELOG.md, upgrade/core.py, test_upgrade_npm_to_python.py correctly preserved — historical records and old-command detection intact | grep verification |
| 3 | [LOW] | Build artifacts (`dist/`, `build/lib/`) still contain old refs — regenerated on next build, not manually editable | `packages/core/dist/`, `pennyfarthing-dist/build/` |
| 4 | [LOW] | pnpm-lock.yaml included in commit — unrelated dirty lockfile inherited from develop | `pnpm-lock.yaml` |
| 5 | [VERIFIED] | No remaining stale refs in active source, docs, scripts, templates, or workflows | grep sweep post-edit |
| 6 | [VERIFIED] | All strings are user-facing messages or comments — no security implications, no injection vectors | `skill.ts`, `command.ts`, `theme.ts`, etc. |
| 7 | [VERIFIED] | `pennyfarthing update` correctly mapped to `pf setup` (setup subsumes update functionality) | `skill.ts:57`, `command.ts:57` |

**Data flow traced:** All changed strings are static error messages, comments, or documentation — no dynamic data, no user input interpolation
**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-24T18:22:44Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T18:10:00Z | 2026-02-24T18:10:00Z | 0m |
| implement | 2026-02-24T18:10:00Z | 2026-02-24T18:21:16Z | 11m 16s |
| review | 2026-02-24T18:21:16Z | 2026-02-24T18:22:44Z | 1m 28s |
| finish | 2026-02-24T18:22:44Z | - | - |