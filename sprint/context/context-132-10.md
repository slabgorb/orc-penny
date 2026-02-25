# Context: 132-10 Add guided tour prompt to pf-setup completion step

## Goal

After `/pf-setup` completes its 11-step project configuration workflow, prompt the developer with an offer to take the guided tour (`guided-tour` workflow). This bridges the gap between setup and onboarding -- the tour exists (132-6, 132-7) but nothing in the setup flow tells developers about it.

## Current State

`step-11-complete.md` is the final step of the `project-setup` workflow. It has five sections:

1. **VALIDATION** (lines 21-67) -- runs `pennyfarthing doctor` and a manual checklist
2. **CONFIGURATION SUMMARY** (lines 69-100) -- table of repos, files created, commands available
3. **QUICK-START GUIDE** (lines 102-134) -- numbered list of dev commands, agents, Cyclist
4. **NEXT STEPS** (lines 136-161) -- checkbox list (immediate, when-ready, customization, resources)
5. **FINAL MESSAGE** (lines 163-187) -- "Setup Complete!" with theme greeting and quick commands

The FINAL MESSAGE section (lines 163-187) currently ends with three quick commands (`/sm`, `/sprint status`, `/help`) and "Happy coding!". There is no mention of the guided tour anywhere in step-11 or any other setup step.

The guided tour workflow (`guided-tour/workflow.yaml`) is a 5-step BikeLane stepped workflow (v2.0.0) with interactive switch gates. It covers: Welcome, Themes, Agents, Sprint, and Config. It uses the `orchestrator` agent. There is currently no `/tour` slash command -- the tour is invoked by loading the workflow directly.

## Technical Approach

**Modify step-11-complete.md** rather than adding a step-12. Rationale:

- Step 11 already owns the "what's next" messaging. Adding the tour prompt here keeps it as part of the natural completion flow.
- A step-12 would add workflow complexity for what is essentially one additional sentence in the final output.
- The prompt fits naturally between the FINAL MESSAGE and the WORKFLOW COMPLETE sections.

Specific changes to `step-11-complete.md`:

1. **Add a GUIDED TOUR section** between FINAL MESSAGE (line 187) and WORKFLOW COMPLETE (line 189). This section should present an `AskUserQuestion` prompt asking whether the developer wants to take the tour now, skip it, or learn how to start it later.

2. **Add `/guided-tour` to the NEXT STEPS section** under the IMMEDIATE checklist (around line 145), e.g.: `Run /guided-tour for an interactive walkthrough of key features`.

3. **Add `/guided-tour` to the quick commands in FINAL MESSAGE** (around line 179-180).

The prompt should use the switch-gate pattern from 132-7 so it integrates cleanly with the BikeLane engine:

```
Would you like to take the guided tour? It walks through themes,
agents, sprints, and configuration in about 5 minutes.

  [Y] Yes, start the tour    -- Load guided-tour workflow step 1
  [L] Later                   -- Show how to start it manually
  [S] Skip                    -- Proceed without tour
```

If the user selects "Yes", the agent should load the guided-tour workflow (`cat .pennyfarthing/workflows/guided-tour/workflow.yaml` then begin step-01-welcome). If "Later", show the manual invocation command. If "Skip", proceed to the existing WORKFLOW COMPLETE epilogue.

Additionally, a `/guided-tour` or `/tour` slash command should be created in `pennyfarthing-dist/commands/` so the "Later" option has something concrete to reference. This is a thin command file that loads the `guided-tour` workflow, similar to how `pf-setup.md` loads `project-setup`.

## Key Files

| File | Action |
|------|--------|
| `pennyfarthing/pennyfarthing-dist/workflows/project-setup/steps/step-11-complete.md` | Modify -- add tour prompt section, update NEXT STEPS and FINAL MESSAGE |
| `pennyfarthing/pennyfarthing-dist/commands/pf-tour.md` | Create -- thin slash command to launch the guided-tour workflow |
| `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/workflow.yaml` | Read-only reference -- no changes needed |
| `pennyfarthing/pennyfarthing-dist/commands/pf-setup.md` | Read-only reference -- pattern for the new command file |

## Dependencies

- **132-6** (Create Guided Tour Stepped Workflow) -- DONE. Created the 5-step guided-tour workflow.
- **132-7** (Enhance guided tour with interactive deep-dives) -- DONE. Added switch gates, interactive menus, AskUserQuestion integration.
- No blocking dependencies remain. Both prerequisite stories are complete and merged.

## Acceptance Criteria

1. After `/pf-setup` step-11 completes validation and shows the final message, the user is prompted with an offer to take the guided tour.
2. Selecting "Yes" loads and begins the `guided-tour` workflow starting at step-01-welcome.
3. Selecting "Later" shows the user how to start the tour manually (e.g., `/guided-tour`).
4. Selecting "Skip" completes setup normally without the tour.
5. A `/guided-tour` (or `/tour`) slash command exists so the tour can be started independently at any time.
6. The NEXT STEPS checklist in step-11 mentions the guided tour as a recommended immediate action.
7. The tour prompt uses AskUserQuestion (switch-gate pattern from 132-7), not a plain text prompt.
