# Narrative

## Problem Statement
**Problem:** Our developer tooling was accidentally including sensitive system information — like the developer's username and the full layout of their computer's file system — in routine data responses. **Why it matters:** Any tool, plugin, or log-aggregation system reading these responses could harvest details that help an attacker understand the target environment. This is the kind of low-effort, high-value reconnaissance data that precedes more serious breaches.

---

## What Changed
Think of it like a hotel key card. The card gets you into your room — it doesn't need your home address printed on it. Previously, when the app answered questions like "what project are you working on?" or "what files are in this repo?", it was handing back the full home address along with the room key.

This fix trims those answers down to only what's needed:
- **Project location** now returns just the folder name (e.g., `my-project`), not the full path (e.g., `/Users/alice/Work/clients/acme/my-project`)
- **Git file listings** now return clean relative names instead of system-rooted paths
- An earlier fix (story 160-19) already closed a related leak in error messages — this story closes the remaining two doors that were still open

---

## Why This Approach
The fix is surgical on purpose. We didn't rebuild how these endpoints work — we just filtered what they're allowed to say. `basename()` strips everything before the last folder separator, so the response tells you *what* without telling you *where*. Omitting paths entirely for git listings achieves the same goal with zero risk of accidentally re-including sensitive segments.

This approach is preferred over, say, encrypting or hashing the paths, because the downstream consumers (UI panels, dashboards) genuinely don't need that information. Giving them less is safer and simpler than giving them a scrambled version of something they shouldn't have.

---
