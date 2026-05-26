# Story 123-1: Package contents assertion test and npm pack gate

**Jira:** PROJ-15366
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/123-1-package-contents-assertion
**Assignee:** slabgorb@gmail.com

---

## Story Context

Run `npm pack --dry-run` and assert tarball contents against a known-good manifest before publishing. Catches missing files that slipped through in 11.3.x releases.

### Acceptance Criteria
- [ ] Test runs `npm pack --dry-run` on `pennyfarthing-dist/`
- [ ] Asserts tarball contents match a known-good manifest file
- [ ] Test fails if unexpected files are missing or extra files appear
- [ ] Integrated as a gate in the publish/release workflow
- [ ] Catches the kind of missing-file regressions seen in 11.3.x

### Technical Approach
- Create a manifest file listing expected package contents
- Write a test that runs `npm pack --dry-run`, parses output, compares against manifest
- Add as a pre-publish gate (CI or justfile recipe)

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core deliverable — the test IS the feature

**Test Files:**
- `tests/unit/test_package_contents.sh` - Runs `npm pack --dry-run --json`, parses tarball file list, asserts against manifest (37 assertions)
- `tests/integration/test_pack_gate.sh` - Verifies the content test is wired into the publish pipeline (1 failing — the gate)
- `tests/fixtures/package-manifest.json` - Known-good manifest: required root files, top-level dirs, pennyfarthing-dist subdirs, critical files, scripts

**Tests Written:** 41 assertions covering 5 ACs
**Status:** RED (integration test fails — gate not wired into publish workflow)

**What passes (unit):** All 37 content assertions — root files, dirs, pennyfarthing-dist subdirs, critical files, scripts, non-empty dirs, no unexpected entries
**What fails (integration):** Gate not integrated into prepublishOnly, justfile, or test runner

**For Dev:**
- Wire `tests/unit/test_package_contents.sh` into the publish pipeline (justfile recipe, prepublishOnly, or test runner)
- The content test itself is complete and passing — don't modify it
- The integration test (`test_pack_gate.sh`) checks for wiring in: `package.json` prepublishOnly, justfile recipe (`pack-check`/`pack-gate`/`check-pack`/`validate-pack`), or `tests/run-tests.sh`

**Note:** AC1 says "on pennyfarthing-dist/" but the actual npm package is `@pennyfarthing/core` at the repo root. The test runs `npm pack` at the repo root, which is correct.

**Handoff:** To Dev for gate integration

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `package.json` - Added `test_package_contents.sh` to `prepublishOnly` script chain
- `tests/run-tests.sh` - Added "Package Contents" test to the test runner

**Tests:** 4/4 integration + 37/37 unit = 41/41 passing (GREEN)
**Branch:** feat/123-1-package-contents-assertion (pushed)

**What was done:**
- Wired `tests/unit/test_package_contents.sh` into `prepublishOnly` in `package.json` — runs automatically before every `npm publish`
- Added test to `tests/run-tests.sh` so it runs in normal test suite too
- Both integration points detected by `test_pack_gate.sh`

**AC coverage:**
- [x] AC1: Test runs `npm pack --dry-run` (unit test)
- [x] AC2: Asserts against known-good manifest (unit test)
- [x] AC3: Fails on missing/extra files (unit test)
- [x] AC4: Integrated as prepublish gate + test runner (integration test)
- [x] AC5: Catches 11.3.x regressions (manifest covers all critical paths)

**Note:** Pre-existing "Reference Integrity" test failure unrelated to this story (missing personas/themes dir).

**Handoff:** To Reviewer

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Manifest JSON → python3 parser → shell loops → grep against npm pack file list → pass/fail counters → exit code. All paths from resolved SCRIPT_DIR.

**Pattern observed:** Good separation of concerns — manifest (data), unit test (assertion engine), integration test (wiring check). Each can evolve independently. Follows existing test patterns at `tests/unit/` and `tests/integration/`.

**Error handling:** Pre-flight checks catch missing manifest, missing python3, empty pack output. No silent failures on the critical path.

**Observations:**
- `[VERIFIED]` Temp file cleanup, cwd-independent invocation, prepublishOnly chain safety, actual pack output validation
- `[LOW]` npm stderr swallowed — diagnostic info lost on unexpected failures (`test_package_contents.sh:51`)
- `[LOW]` Non-empty check uses `>0` not minimum thresholds — partial file loss within a directory not caught (`test_package_contents.sh:226`)

**Handoff:** To SM for finish-story

---

## Phase Log