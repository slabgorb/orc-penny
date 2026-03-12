# Standalone: Add esbuild CJS banner fix and consumer E2E test suite

**Jira:** MSSCI-16292
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16292-esbuild-cjs-banner-e2e
**PR:** 1306
**Started:** 2026-03-07
**Completed:** 2026-03-07

---

## Description

Replace fragile post-build regex CJS patch in build-wheelhub.sh with esbuild
--banner:js flag. Add Docker-based E2E test suite (6 scenarios, 107 assertions)
covering pf init, WheelHub Node 24 startup, content preservation, upgrade safety,
and idempotency. Add e2e-consumer-tests to release-ready gate. Remove obsolete
npm-era consumer install smoke test.

## Files Changed

| File | Change |
|------|--------|
| scripts/build-wheelhub.sh | Added --banner:js, removed 43-line regex patch |
| pennyfarthing-dist/src/pf/_dist/server/wheelhub.mjs | Rebuilt with createRequire banner |
| pennyfarthing-dist/gates/release-ready.md | Added e2e-consumer-tests check |
| pennyfarthing-dist/workflows/release/steps/step-01-preflight.md | Added E2E gate step |
| .github/workflows/ci.yml | Removed disabled smoke-test job |
| tests/e2e/* | New E2E test suite (10 files) |
| tests/integration/test_consumer_install.sh | Deleted (obsolete npm-era test) |
