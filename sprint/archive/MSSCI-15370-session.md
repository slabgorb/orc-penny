<session story="123-5" workflow="trivial">
  <meta>
    <jira>MSSCI-15370</jira>
    <points>1</points>
    <started>2026-02-22</started>
  </meta>

  <status phase="setup" next-agent="dev" handoff-ready="true"/>

  <acceptance-criteria>
    <ac id="1" status="pending">Document pnpm publish requirement in CONTRIBUTING.md</ac>
    <ac id="2" status="pending">Document in release workflow that pnpm publish must be used</ac>
    <ac id="3" status="pending">Document in justfile that pnpm publish is required</ac>
  </acceptance-criteria>

  <context>
    Adding documentation about the pnpm publish requirement in the Pennyfarthing workspace. npm publish can leak literal workspace:* refs which breaks the workspace configuration. This needs to be documented in multiple places to ensure the team is aware of this constraint.

    Key files to update:
    - CONTRIBUTING.md
    - Release workflow documentation
    - justfile
  </context>

## SM Assessment

Story setup complete. Jira MSSCI-15370 claimed and moved to In Progress.
Branch `chore/document-pnpm-publish-gotchas` created from main.
Trivial workflow: setup → implement → review → finish.
Handoff to Dev (Ponder Stibbons) for documentation updates.
Three files need pnpm publish warnings: CONTRIBUTING.md, release workflow docs, justfile.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/CONTRIBUTING.md` - New file documenting pnpm publish requirement
- `pennyfarthing/scripts/deploy.sh` - Fixed root package publish from npm to pnpm, added warning comment
- `pennyfarthing/justfile` - Added `publish` recipe with pnpm requirement warning

**Tests:** N/A (documentation-only changes)
**Branch:** chore/document-pnpm-publish-gotchas (pushed to pennyfarthing repo)

**Notes:** Also fixed an actual bug — deploy.sh line 369 used `npm publish` for the root package. While the root package.json currently has no `workspace:*` deps, this was inconsistent with the workspace packages (which correctly used `pnpm publish`) and a latent risk.

**Handoff:** To Granny Weatherwax (Reviewer) for code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Docs → developer follows pnpm pattern → workspace:* resolved. deploy.sh automated path also correct. justfile recipe enforces pnpm.
**Pattern observed:** Consistent `--no-git-checks` flag usage across root (line 371) and workspace (line 379) publish commands at `scripts/deploy.sh`
**Error handling:** `just publish nonexistent` fails naturally (cd: no such directory). Acceptable for dev helper.
**Low findings:** `npm config set` auth token (deploy.sh:358) is a minor inconsistency now that all publish commands use pnpm. Non-blocking — pnpm reads npm config natively.
**Handoff:** To Captain Carrot (SM) for finish-story

  <work-log>
    <entry agent="sm" date="2026-02-22">
      Setup complete. Session file created, branch ready for developer.
      Story: Trivial workflow (setup → implement → review → finish)
      Points: 1
      Priority: P1
      Jira MSSCI-15370 claimed and assigned.
    </entry>
  </work-log>
</session>