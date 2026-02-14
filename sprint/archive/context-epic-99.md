# Epic 99 — Sprint CLI Bug Fixes

**Jira:** MSSCI-14938
**Type:** epic
**Priority:** P1
**Status:** backlog
**Repos:** pennyfarthing

## Overview

Epic 99 tracks critical bugs in the `pf sprint` CLI command suite discovered during active sprint work. These are high-priority issues that impact the developer workflow.

## Stories

### 99-1: Fix pf sprint story finish when Jira key missing from shard YAML

**Status:** backlog | **Points:** 2 | **Priority:** P1 | **Jira:** MSSCI-14939

The `pf sprint story finish` command fails when attempting to resolve the Jira key from a story in an epic shard YAML file. The fallback lookup mechanism does not correctly handle stories where the Jira key exists in the shard but not in the session file.

**Root cause:** Improper error handling in the fallback Jira key resolution logic in `story_finish.py`.

### 99-2: Fix story finish archive missing required sprint fields

**Status:** done | **Points:** 1 | **Priority:** P1 | **Jira:** MSSCI-14940

The story finish command failed to validate that all required sprint metadata fields are present before attempting to archive and transition the story.

**Completed:** 2026-02-11

## Dependencies

None. Stories can be worked independently.

## Context

These bugs were identified during sprint execution and should be fixed immediately to unblock the developer workflow. All stories follow the **trivial workflow** (SM → Dev → Reviewer → SM).
