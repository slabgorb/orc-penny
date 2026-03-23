# Narrative

## Problem Statement
Problem: When running a Peloton session — our automated team workflow — the system sometimes opened multiple terminal panels for the same agent role (e.g., two "Developer" panels running simultaneously). Why it matters: Duplicate panels caused agents to step on each other's work, produced conflicting outputs, wasted compute, and made it impossible to trust which panel's result was authoritative. It undermined confidence in the very system we're building to improve code quality.

---

## What Changed
Think of Peloton like an air traffic control system for AI agents. Each agent (Developer, Reviewer, Test Engineer) gets assigned one "runway" — a dedicated terminal panel — to do their work. The bug was that the system sometimes forgot it had already assigned a runway, and opened a second one for the same agent.

The fix adds a "registry check" before opening any new panel: if that agent already has a panel, use the existing one instead of creating a new one. One role, one runway. Always.

---

## Why This Approach
The simplest reliable fix is a guard at the door: check before you open. Rather than trying to clean up duplicates after the fact — which risks interrupting work already in progress — we prevent duplicates from being created in the first place. This is a small, surgical change that doesn't touch the broader orchestration logic, so it's low risk and easy to verify.

---

## Before/After
| | Before | After |
|---|---|---|
| **Panel count per role** | 1–N (unpredictable) | Always exactly 1 |
| **What happened on re-trigger** | New panel opened alongside existing one | Existing panel reused |
| **Agent behavior** | Two agents executing independently, potentially conflicting | Single agent with clear ownership |
| **Output trustworthiness** | Ambiguous — which panel's result is canonical? | Unambiguous — one result per role |
| **Recovery required?** | Yes — user had to manually kill duplicate panes | No — system self-corrects |
| **Example `tmux list-panes` output** | `dev`, `dev`, `reviewer`, `tea` | `dev`, `reviewer`, `tea` |
