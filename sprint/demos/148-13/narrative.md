# 148-13

## Problem

Problem: When a developer opened a second terminal tab or ran `pf tmux` commands while already inside a Pennyfarthing tmux session, the system would either attach to the wrong session or spawn an unnecessary nested session rather than recognizing the one already running. Why it matters: Agents running pane management commands could end up targeting the wrong environment — sending commands to stale sessions, losing context, or creating duplicate sessions that confused the pane registry.

---

## What Changed

Think of tmux sessions like conference rooms. Before this fix, when you asked "which room are we in?", the system would look at a directory listing and always pick the first room alphabetically — even if you were already *sitting in* a different room. After the fix, the system asks the building's intercom: "which room am I currently in?" and only falls back to the directory if the intercom doesn't answer (i.e., you're calling from outside a room entirely). It also now knows to prefer properly-named rooms over placeholder "bare" rooms created just to keep the lights on.

---

## Why This Approach

tmux has a built-in way to ask "what session am I attached to right now?" — a command called `display-message`. It's instant and always correct when you're inside a session. The old code skipped this and went straight to `list-sessions`, which returns sessions in alphabetical order. That list-based approach has two problems: it ignores which session you're *in*, and when multiple sessions exist, it picks the wrong one by accident. The new approach uses the direct query first and only falls back to the list when genuinely needed (e.g., running from outside tmux entirely). The fallback also now filters out "bare" auto-start sessions — temporary placeholder sessions that exist just to keep the server alive — so that real development sessions are always preferred.

---
