# Installation Overhaul - Epic Breakdown

## Overview

Overhaul the Pennyfarthing installation system to be cleaner, more robust, and self-testing. The current install scatters files across `.claude/` and `.pennyfarthing/`, making it hard to reason about what Pennyfarthing owns vs user files. The init/update scripts need updating for the new structure, and the install should bootstrap itself then hand off to an interactive workflow for configuration. End-to-end testing with real repos ensures it actually works.

**Points:** 34

## Epic 1: Clean Install Consolidation

**User Outcome:** All Pennyfarthing-managed files live under `.pennyfarthing/`, init bootstraps then hands off to an interactive workflow, and the install is validated against real repos.

### Story 1.1: Audit and map all files Pennyfarthing produces outside .pennyfarthing

As a framework developer,
I want **a complete inventory of every file and directory Pennyfarthing creates outside `.pennyfarthing/`**,
So that we know the full scope of what needs to move.

**Acceptance Criteria:**

**Given** a fresh `pennyfarthing init` or `pennyfarthing update` run
**When** I audit the project directory
**Then** every file created by Pennyfarthing outside `.pennyfarthing/` is documented
**And** each file has a migration plan (move, symlink, or deprecate)

### Story 1.2: Move settings.local.json generation into .pennyfarthing

As a framework developer,
I want **settings.local.json to be generated at `.pennyfarthing/settings.local.json` with a symlink at `.claude/settings.local.json`**,
So that the source of truth is in our namespace while Claude Code still discovers it.

**Acceptance Criteria:**

**Given** `pennyfarthing init` runs on a fresh project
**When** settings.local.json is created
**Then** the canonical file is at `.pennyfarthing/settings.local.json`
**And** `.claude/settings.local.json` is a symlink to it
**And** existing installs with a real file at `.claude/settings.local.json` are migrated on update

### Story 1.3: Move persona-config.yaml into .pennyfarthing

As a framework developer,
I want **persona configuration to live at `.pennyfarthing/config.local.yaml` exclusively**,
So that theme config is consolidated under our namespace.

**Acceptance Criteria:**

**Given** a project with `.claude/persona-config.yaml`
**When** `pennyfarthing update` runs
**Then** the config is moved to `.pennyfarthing/config.local.yaml`
**And** any code reading persona config checks the new location first
**And** doctor detects and offers to migrate the old location

### Story 1.4: Move project hooks into .pennyfarthing/project

As a framework developer,
I want **project-specific hooks (setup-env.sh etc.) to live under `.pennyfarthing/project/` instead of `.claude/project/`**,
So that all Pennyfarthing-managed files are in one place.

**Acceptance Criteria:**

**Given** a project with hooks at `.claude/project/hooks/`
**When** `pennyfarthing update` runs
**Then** hooks are moved to `.pennyfarthing/project/hooks/`
**And** settings.local.json hook paths are updated to reference the new location
**And** `.claude/project/hooks/` is cleaned up if empty

### Story 1.5: Consolidate sidecars directory

As a framework developer,
I want **sidecars to remain at `.pennyfarthing/sidecars/` and remove any `.claude/sidecars/` references**,
So that agent learning files are only in one location.

**Acceptance Criteria:**

**Given** an install that may have sidecars in both locations
**When** `pennyfarthing update` runs
**Then** any `.claude/sidecars/` content is merged into `.pennyfarthing/sidecars/`
**And** references to `.claude/sidecars/` are updated throughout

### Story 1.6: Update init command for bootstrapping install

As a framework user,
I want **`pennyfarthing init` to do minimal bootstrapping (create .pennyfarthing, install core files, register hooks) then hand off to an interactive setup workflow**,
So that the install is quick and the user can configure interactively.

**Acceptance Criteria:**

**Given** a project without Pennyfarthing installed
**When** I run `pennyfarthing init`
**Then** `.pennyfarthing/` is created with core files and scripts
**And** hooks are registered in `.claude/settings.local.json`
**And** the command prints instructions to start the interactive setup workflow
**And** the interactive workflow guides theme selection, sprint setup, and persona config

### Story 1.7: Update update command for file migration

As a framework user,
I want **`pennyfarthing update` to detect files in old locations and migrate them to `.pennyfarthing/`**,
So that existing installs are brought up to the new structure.

**Acceptance Criteria:**

**Given** a project installed with an older version of Pennyfarthing
**When** I run `pennyfarthing update`
**Then** files are migrated from `.claude/` to `.pennyfarthing/` equivalent paths
**And** symlinks are created where Claude Code expects to find files
**And** the manifest is updated to reflect the new layout
**And** doctor passes after update completes

### Story 1.8: Update doctor to validate new file layout

As a framework user,
I want **`pennyfarthing doctor` to check for files in the correct `.pennyfarthing/` locations and flag old-location files**,
So that I can verify my install is up to date.

**Acceptance Criteria:**

**Given** a project with mixed old/new file locations
**When** I run `pennyfarthing doctor`
**Then** files in old locations are flagged with migration instructions
**And** `--fix` migrates them automatically
**And** the Cyclist spawn-helper check (already added) continues to work

### Story 1.9: End-to-end test - fresh repo install

As a framework developer,
I want **an automated test that creates a new repo, runs `pennyfarthing init`, validates with doctor, and exercises the just scripts**,
So that fresh installs are proven to work.

**Acceptance Criteria:**

**Given** a temporary empty git repo
**When** the test runs `pennyfarthing init` and `pennyfarthing doctor`
**Then** doctor reports all checks passing
**And** the just scripts (dev, test, build) are functional
**And** the test cleans up the temporary repo afterward

### Story 1.10: End-to-end test - existing repo upgrade

As a framework developer,
I want **an automated test that sets up an old-style install, runs `pennyfarthing update`, and validates the migration**,
So that upgrades from old layouts are proven to work.

**Acceptance Criteria:**

**Given** a temporary repo with files in old `.claude/` locations
**When** the test runs `pennyfarthing update` and `pennyfarthing doctor`
**Then** doctor reports all checks passing
**And** files have been migrated to `.pennyfarthing/`
**And** symlinks exist where needed for Claude Code compatibility
**And** the test cleans up afterward
