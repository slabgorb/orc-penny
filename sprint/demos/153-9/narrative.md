# Narrative

## Problem Statement
**Problem:** Running the automated test suite would silently switch the codebase to a different code branch mid-run, breaking any work in progress and causing unrelated tests to fail with misleading errors. **Why it matters:** Developers lost time debugging phantom failures that had nothing to do with their actual code changes — the test suite itself was secretly corrupting the environment it was supposed to be verifying. This struck twice during active development of the Pennyfarthing framework, each time requiring manual recovery before work could resume.

---

## What Changed
Imagine a building inspector who, while checking one apartment, accidentally leaves your front door unlocked and rearranges your furniture. The inspector was supposed to be working in a test apartment (a temporary copy), but accidentally used the real building's master key.

That's what was happening in our automated tests. Two specific tests were exercising the "create a new code branch" functionality by handing it a shortcut (`.`) that resolves to wherever you're currently standing — which happened to be the live codebase. The tests ran, checked out a branch called `feature/test` on the real repo, and never cleaned up after themselves.

The fix: give those two tests their own private temporary workspace (a throwaway git repository created for the test and deleted afterward), so they can do anything they want without ever touching the real codebase. No production code changed — the git helper functions were already written correctly. This was purely a housekeeping fix in the test files themselves. A permanent guard was also added: a watchdog test that proves the broader test suite can run from start to finish without changing the live repo's branch.

---

## Why This Approach
The intuitive fix might have been to add a safety check to the production git utility: "if someone passes you the live repo path, refuse." That was rejected for a good reason — the utility is *supposed* to work on whatever repo you hand it, including the live one. Adding a guard there would have broken legitimate uses like `pf git branches .` (explicitly managing branches in the current directory). The bug was never in the utility; it was in the tests misusing it.

Fixing tests in the test files is cleaner, narrower, and doesn't add defensive code that compensates for a problem that no longer exists. The regression guard (the watchdog test) catches any future slip of this kind at the source — if a test ever again reaches out and touches the live repo's branch, the guard fails loudly before it can do damage.

---

## Before/After
| | Before | After |
|---|---|---|
| **Test setup** | `("good-repo", Path("."))` — the live repository | `("good-repo", temp_git_repo)` — a throwaway `tmp_path` fixture |
| **Running the full test suite** | Working branch silently switches to `feature/test` | Working branch unchanged; suite exits cleanly |
| **Downstream effect** | `loader.py` missing `find_story_in_data` on the leaked branch → cascading import failures in unrelated modules | No cascading failures; each test isolated to its own temporary repo |
| **Detectability** | No error on the leak itself — only confusing failures appear later | Watchdog test (`test_partial_failure_tests_do_not_leak_branch_to_outer_repo`) fails immediately if the leak is reintroduced |
| **False-green risk** | Tests passed while silently corrupting state | Watchdog asserts `returncode == 0` (real run) and verifies `develop` branch exists before running — cannot pass vacuously |
| **Static guard** | None | AST-based scan rejects `Path(".")`, `Path.cwd()`, `os.getcwd()`, `Path(os.curdir)` in test files — ignores comments/docstrings, catches all four live-cwd vectors |
| **Production code change** | N/A | None — `create_branches.py` was already correct; fix is test-only |
