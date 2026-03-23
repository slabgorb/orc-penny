# Narrative

## Problem Statement
Problem: The peloton skill — a tool that runs multiple AI agents simultaneously on a story — would get stuck in an endless loop when used from any project other than the Pennyfarthing framework itself. Why it matters: The peloton skill is intended to help teams run full agent pipelines (tester, developer, reviewer) in parallel. If it can't be used from consumer projects, the entire multi-agent workflow feature is effectively unavailable to real users in real projects — which is most of the value proposition.

---

## What Changed
Imagine a megaphone that, when you speak into it, picks up its own echo and keeps amplifying it forever. That's what was happening.

When a consumer project invoked the peloton skill, the skill would look for its configuration and accidentally find itself again — triggering another invocation, which triggered another, and so on. The fix teaches the skill to recognize when it's been called from outside its "home" and stop the loop before it starts.

---

## Why This Approach
The simplest reliable fix was to add a self-awareness check at the entry point: "Am I already running? Was I called from a context that would cause me to call myself?" Rather than restructuring the entire invocation chain, a guard at the door prevents the problem without touching the core logic. For a 1-point bug, this is the right scope — minimal change, maximum stability.

---

## Before/After
| | Before | After |
|---|---|---|
| **Behavior when invoked** | Skill calls itself recursively | Skill runs normally |
| **Error output** | None — silent infinite loop | N/A — no error occurs |
| **Recovery required** | Manual process kill (`Ctrl+C` or kill signal) | None |
| **Usable from consumer projects** | No | Yes |
| **Usable from framework source** | Yes | Yes (unchanged) |
| **Impact on peloton pipeline** | Completely blocked for real projects | Fully operational |
