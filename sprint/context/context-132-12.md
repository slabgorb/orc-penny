# Context: 132-12 Add just status dual-repo git wrapper

## Goal

New developers running `git status` only see orchestrator changes. The inlined `pennyfarthing/` repo (separate git history) is invisible. A `just status` recipe surfaces both repos' status in one command, clearly labeled.

## Technical Approach

Add a `status` recipe to the root `justfile` under a new "Git" section. The recipe runs `git status` in the orchestrator root and then `git -C pennyfarthing/ status`, with clear headers labeling each repo and its target branch:

- **Orchestrator** (targets `main`, trunk-based)
- **pennyfarthing/** (targets `develop`, gitflow)

Use the existing `root` and `pennyfarthing` variables already defined at the top of the justfile. Keep it a simple bash recipe consistent with the existing patterns (shebang, `set -euo pipefail`).

## Key Files

- `justfile` -- add the `status` recipe

## Acceptance Criteria

- `just status` prints labeled git status for both repos
- Each section header identifies the repo name and its default branch
- Works from the project root regardless of `pennyfarthing/` state
- Recipe appears in `just --list` output
