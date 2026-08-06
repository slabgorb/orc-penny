# 162-25

## Problem

**Problem:** A branch-tracking component incorrectly marked work as "complete" when a branch name contained special git revision syntax. Why it matters: teams could see a story show up as merged and done in the sprint board when the actual code was never merged — a silent false positive that erodes trust in automated status tracking and could cause teams to move on from work that wasn't actually shipped.

---

## What Changed

Imagine your project management tool checks whether a feature has been delivered by asking a source control system "is this branch merged?" The system does that by looking up the branch by name. If the branch name contains certain special characters (like `~2`, `^`, or `@{0}` — shorthand that git uses to mean "go back two commits"), git helpfully answers the question — but about an *older* version of the branch, not the current tip. The ancestor almost always looks merged, so the tracker declares success. Nothing was actually delivered.

The fix adds an explicit name-validity check before any lookup happens. Git has a built-in validator (`git check-ref-format --branch`) that immediately rejects these malformed names with an error code. When that check fails, the tracker now routes the input to its existing "unknown branch — abort" path instead of silently querying the wrong commit.

Two additional edge cases were closed at the same time: a branch name ending in a shell command-substitution pattern (like `$(rm -rf /)`) was being silently trimmed to just its first character before being used — changing the value instead of refusing it. And branch names containing invisible control characters were passing validation and being handed to git, which would loudly abort — noisy but unpredictable. Both now fail at the validation gate.

---

## Why This Approach

Git already has the right tool for this: `git check-ref-format --branch` is the canonical way to ask "is this a valid branch name?" rather than trying to enumerate every possible special character ourselves. Maintaining a custom blocklist would be an arms race — git's own validator knows every edge case because it ships with git.

Routing failures to the existing unknown-branch abort path means no new error-handling branches were introduced. The fix is narrow: one validation call, one routing decision. Systems that were already handling legitimate unknown branches correctly continue to work the same way.

---
