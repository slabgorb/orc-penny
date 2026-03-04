---
stepsCompleted: [step-01, step-02, step-03, step-04, step-05]
inputDocuments:
  - "Plan: Pennyfarthing Developer Discovery & Onboarding (session transcript)"
---

# Developer Discovery & Onboarding - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Developer Discovery & Onboarding, addressing the gap between Pennyfarthing's 60 commands, 18 agents, and 33 guides and new developers' ability to find and use them.

## Requirements Inventory

### Functional Requirements

FR1: New developers must have a single "read this first" guide organized by user intent
FR2: The welcome banner must surface the three most useful entry points every session
FR3: A concise reference card must explain what the system handles automatically
FR4: Claude must proactively suggest capabilities when users do things manually
FR5: The command listing must not include deprecated entries that add noise

### NonFunctional Requirements

NFR1: All guides must reflect current system behavior (no aspirational features)
NFR2: Guides must follow existing pennyfarthing-dist/guides/ formatting conventions
NFR3: Welcome banner change must not break existing hook functionality
NFR4: Deprecated command removal must not break any active functionality

### Additional Requirements

- Guides go in `pennyfarthing/pennyfarthing-dist/guides/`
- Use `<info>` boxes for key points, tables for reference data, `<critical>` for must-know items
- Welcome banner tip line must respect existing ASCII art formatting
- CLAUDE.md template change applies to `pennyfarthing init` generated output

### FR Coverage Map

FR1: Epic 132, Story 132-1 - Getting Started Guide
FR2: Epic 132, Story 132-2 - Welcome Banner Discovery Nudge
FR3: Epic 132, Story 132-3 - What Pennyfarthing Does Reference Card
FR4: Epic 132, Story 132-4 - CLAUDE.md Developer Guidance Section
FR5: Epic 132, Story 132-5 - Deprecated Command Cleanup

## Epic List

### Epic 132: Developer Discovery & Onboarding
New developers joining a Pennyfarthing project can discover capabilities, set up their workspace, and start productive work without needing tribal knowledge.
**FRs covered:** FR1, FR2, FR3, FR4, FR5

## Epic 132: Developer Discovery & Onboarding

New developers joining a Pennyfarthing project can discover capabilities, set up their workspace, and start productive work without needing tribal knowledge or the creator's guidance.

### Story 132.1: Create Getting Started Guide

As a new developer joining a Pennyfarthing project,
I want a single "read this first" document organized by intent,
So that I can discover what's available and become productive without tribal knowledge.

**Acceptance Criteria:**

**Given** a new developer has Pennyfarthing installed
**When** they read `guides/getting-started.md`
**Then** they understand why structured agent workflows beat ad-hoc chat
**And** they can set up their workspace (tmux, BikeRack, or Cyclist)
**And** they can run their first session using `/pf-work`
**And** they know the TDD cycle (SM -> TEA -> Dev -> Reviewer -> SM)
**And** they have a top-10 quick reference table organized by intent

### Story 132.2: Add Welcome Banner Discovery Nudge

As a developer starting a new session,
I want the welcome banner to show me the three most useful entry points,
So that I don't need to memorize commands to get started.

**Acceptance Criteria:**

**Given** a developer starts a Claude Code session in a Pennyfarthing project
**When** the session-start hook displays the welcome banner
**Then** a tip line appears after the ASCII art: `Tip: Type /pf-work to start . /pf-help for all commands . /pf-sprint for status`
**And** the tip line respects the existing banner formatting
**And** no existing functionality is broken

### Story 132.3: Create "What Pennyfarthing Does For You" Reference Card

As a developer using Pennyfarthing,
I want a concise reference card explaining what the system handles automatically,
So that I stop doing manually what the system already does for me.

**Acceptance Criteria:**

**Given** a developer reads `guides/what-pennyfarthing-does.md`
**When** they look for a specific capability category
**Then** they find it organized by domain: session management, quality enforcement, sprint tracking, agent specialization, workspace integration, git automation
**And** each item explains what it does and how to access it
**And** the document is single-page length (not a deep dive)
**And** content matches current system behavior (no aspirational features)

### Story 132.4: Add Developer Guidance Section to CLAUDE.md Init Template

As a developer using Claude in a Pennyfarthing project,
I want Claude to proactively suggest capabilities when I'm doing things manually,
So that I discover features at the moment they're relevant.

**Acceptance Criteria:**

**Given** a project initialized with `pennyfarthing init`
**When** the generated CLAUDE.md is read by Claude
**Then** it contains a "Developer Guidance" section with contextual nudges
**And** nudges map manual actions to Pennyfarthing equivalents (Jira -> `/pf-jira`, tests -> `/tea`, commits -> `/pf-git cleanup`, starting work -> `/pf-work`)
**And** the section instructs natural suggestion, not lecture

### Story 132.5: Remove Deprecated Skill and Command Files

As a new developer scanning the command list,
I want to see only active commands without deprecated noise,
So that I can quickly find what I need without wading through ~15 "DEPRECATED: Use X instead" entries.

**Acceptance Criteria:**

**Given** all deprecated skills/commands are identified
**When** deprecated files are removed from `pennyfarthing-dist/skills/` and `pennyfarthing-dist/commands/`
**Then** `/pf-help` no longer lists deprecated entries
**And** the command registry (`command-registry.yaml`) is updated
**And** no active functionality is broken by the removal
**And** a migration note is added if any external docs reference old command names
