<gate name="pf-init-impact" model="haiku">

<purpose>
Project-local dev-exit extension for pennyfarthing-orchestrator.
Checks whether changes to pennyfarthing-dist/ could overwrite consumer
project-local customizations on next pf init or framework upgrade.

This project dogfoods the framework — changes here ship to all consumers.
</purpose>

<pass>
Scan changed files (`git diff --name-only develop...HEAD`) for any paths
under `pennyfarthing-dist/` or `pennyfarthing/pennyfarthing-dist/`.

For each changed file, check:

**1. Overwrite risk**
Does this file get copied to `.pennyfarthing/` on `pf init`? If so:
- Is it a seed-once file (config, local gates) or always-overwrite (scripts, agents)?
- Seed-once files must use copy-if-not-exists, never overwrite
- If unclear, flag it

**2. Backwards compatibility**
- New required fields in YAML schemas: do existing installs still parse?
- Renamed or removed files: do existing references break?
- Changed gate behavior: do project-local overrides still take precedence?

**3. Project-local precedence**
- `.pennyfarthing/gates/` must still win over `pennyfarthing-dist/gates/`
- `.pennyfarthing/config.local.yaml` must still override defaults
- Project-local lang-review checklists must not be clobbered

If no `pennyfarthing-dist/` files were changed, or all checks pass:

```yaml
GATE_RESULT:
  status: pass
  gate: pf-init-impact
  message: "No pf-init impact concerns ({N} dist files changed, all safe)"
  checks:
    - name: overwrite-risk
      status: pass
      detail: "No seed-once files modified, or copy-if-not-exists confirmed"
    - name: backwards-compat
      status: pass
      detail: "Schema changes are additive; no removed/renamed files"
    - name: local-precedence
      status: pass
      detail: "Project-local overrides still take precedence"
```
</pass>

<fail>
```yaml
GATE_RESULT:
  status: fail
  gate: pf-init-impact
  message: "pf-init impact concerns found"
  checks:
    - name: overwrite-risk
      status: pass | fail
      detail: "{file} is seed-once but uses overwrite-always pattern"
    - name: backwards-compat
      status: pass | fail
      detail: "{file} removes/renames {thing} — existing installs will break"
    - name: local-precedence
      status: pass | fail
      detail: "{file} changes discovery order — project-local no longer wins"
  recovery:
    - "Use copy-if-not-exists for seed-once files in pf init"
    - "Add migration notes for breaking schema changes"
    - "Verify gate/config discovery order: project-local first, built-in fallback"
    - "Flag as Delivery Finding if unsure about impact"
```
</fail>

</gate>
