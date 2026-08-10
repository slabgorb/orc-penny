# 162-6

## Problem

Problem: When developers finished a story that lived in a sub-project, the system checked the *wrong folder* to see if the code had been merged — it always looked at the top-level project instead of the actual code repository. Why it matters: this caused valid, fully-merged work to appear unmerged, blocking story completion with a false alarm and forcing manual intervention to close out tickets that were already done.

---

## What Changed

Think of it like a post office that always checked the wrong mailbox. The "finish story" process has two checks it runs before marking work complete: (1) look up the pull request status on GitHub, and (2) verify the local copy of the code reflects the merge. Both checks were accidentally hardwired to run from the main project folder — but the actual code lives one level deeper in a sub-folder called `pennyfarthing/`.

The fix teaches both checks to look in the right mailbox: whichever repository the story's code actually lives in. For stories that span *two* repositories, the system now checks *both* — and refuses to close out the story unless every single pull request is merged. One open PR out of two is treated as incomplete, not good enough.

---

## Why This Approach

The simplest correct fix: pass the repository path as a parameter to every command that needs it, rather than letting those commands assume a default location. This is the same principle as giving someone a full street address instead of just a city name.

For the multi-repo case, the logic is conservative by design — when in doubt, don't mark something done. A story that's half-merged is a story that isn't done, full stop. Failing loudly and leaving the story in "in review" status is safer than silently declaring victory on incomplete work.

---
