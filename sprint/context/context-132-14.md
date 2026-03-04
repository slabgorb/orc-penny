# Context: 132-14 Add fresh-clone smoke test to CI

## Goal

Catch onboarding-path regressions before a new developer encounters them. If `pf init`, `pf doctor`, or the guided-tour workflow break, this CI job fails on every PR instead of silently rotting until someone clones fresh.

## Technical Approach

Add a new `fresh-clone-smoke` job to `pennyfarthing/.github/workflows/ci.yml`. The job simulates a developer cloning the repo for the first time and running the bootstrap sequence. It does NOT reuse the existing `build` job's workspace -- it needs a pristine checkout with no cached state.

The existing `smoke-test` job (currently disabled with `if: false`) tested a Node CLI binary that no longer exists. This new job replaces that concept with the Python-based `pf` CLI path. The old job can be removed or left disabled; the new job is a separate concern.

Runner: `[self-hosted, Ubuntu, Common]` to match existing CI jobs. No matrix needed -- this is a single-path validation.

The job should run independently (no `needs:` dependency on `build`) because it must prove the cold-start path works without prior compilation artifacts.

## Key Files

- `pennyfarthing/.github/workflows/ci.yml` -- add the `fresh-clone-smoke` job
- `pennyfarthing/pennyfarthing-dist/src/pf/doctor/` -- health check system invoked by the job
- `pennyfarthing/pennyfarthing-dist/src/pf/init/core.py` -- `pf init` logic (verify_pf_cli, init_project)
- `pennyfarthing/pennyfarthing-dist/workflows/guided-tour/workflow.yaml` -- YAML parsed in step 5
- `pennyfarthing/pennyfarthing-dist/pyproject.toml` -- defines `pennyfarthing-scripts` package and `pf` entry point

## Test Steps

```yaml
fresh-clone-smoke:
  runs-on: [self-hosted, Ubuntu, Common]
  name: Fresh Clone Smoke Test

  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v5
      with:
        python-version: "3.12"

    - name: Setup Node
      uses: actions/setup-node@v4
      with:
        node-version: "20"

    - name: Setup pnpm
      uses: pnpm/action-setup@v2
      with:
        version: 9

    # Step 1 — Clone is handled by actions/checkout above.
    # The checkout IS the fresh clone in CI.

    # Step 2 — Install pf CLI (editable so pf doctor can find everything)
    - name: Install pf CLI
      run: |
        python -m pip install --upgrade pip
        pip install -e ".[dev]"

    # Step 3 — Verify pf --version works
    - name: Verify pf --version
      run: |
        pf --version
        # Capture version for logs
        echo "PF_VERSION=$(pf --version)" >> $GITHUB_ENV

    # Step 4 — Run pf init to bootstrap directory structure
    - name: Run pf init
      run: |
        pf init --non-interactive

    # Step 5 — Run pf doctor and assert all checks pass
    - name: Run pf doctor
      run: |
        pf doctor --json | tee doctor-output.json
        # Assert success field is true
        python -c "import json, sys; data=json.load(open('doctor-output.json')); sys.exit(0 if data['success'] else 1)"

    # Step 6 — Verify guided-tour workflow YAML parses correctly
    - name: Validate guided-tour workflow YAML
      run: |
        python -c "
        import yaml, sys
        from pathlib import Path

        wf_path = Path('pennyfarthing-dist/workflows/guided-tour/workflow.yaml')
        if not wf_path.exists():
            print(f'FAIL: {wf_path} not found')
            sys.exit(1)

        data = yaml.safe_load(wf_path.read_text())
        wf = data.get('workflow', {})

        # Verify required top-level keys
        required = ['name', 'description', 'type', 'steps', 'gates']
        missing = [k for k in required if k not in wf]
        if missing:
            print(f'FAIL: Missing keys: {missing}')
            sys.exit(1)

        # Verify step files exist
        steps_path = wf_path.parent / 'steps'
        step_files = sorted(steps_path.glob('step-*.md'))
        if not step_files:
            print('FAIL: No step-*.md files found in steps/')
            sys.exit(1)

        print(f'OK: guided-tour workflow valid ({len(step_files)} steps)')
        "

    # Step 7 — Install Node packages and build (validates full stack)
    - name: Install Node packages
      run: pnpm install

    - name: Build all packages
      run: pnpm run build
```

## Dependencies

- **Python 3.12** -- required by `pennyfarthing-scripts` (`requires-python = ">=3.11"`)
- **Node 20 + pnpm 9** -- required for `pnpm install` and `pnpm run build` (matches existing CI)
- **PyYAML** -- installed as a dependency of `pennyfarthing-scripts` (listed in pyproject.toml)
- **Self-hosted runner** -- uses `[self-hosted, Ubuntu, Common]` tags consistent with all other CI jobs
- **No secrets required** -- this job needs no NPM_TOKEN, no Jira credentials, no SSH keys beyond checkout

## Risks

- **`pf doctor` checks that may not pass in CI**: The `settings_hooks` check expects `.claude/settings.local.json` with hooks configured. The `node_packages` check expects `node_modules/`. The `theme` check expects a theme in config. Running `pf init` first should satisfy most of these, but some checks (like `settings_hooks`) may need `pf init` to fully scaffold `.claude/settings.local.json`. If `pf doctor` returns warn-level results for `git_hooks` or `node_packages`, those are non-fatal (doctor only fails on `status == "fail"`, not `"warn"`).
- **`pf init --non-interactive` flag**: The init CLI must support a non-interactive mode that skips prompts and uses defaults. If this flag does not yet exist, it needs to be added (the `setup.py` already has `skip_prompts` support, but the CLI flag wiring should be verified).
- **Disabled old smoke-test**: The existing `smoke-test` job (line 60-87) is disabled with `if: false`. The new job should be clearly distinct -- named `fresh-clone-smoke` -- so there is no confusion. Consider removing the dead job in this PR to avoid ambiguity.
- **CI runtime**: The full `pnpm install` + `pnpm run build` step adds several minutes. If this becomes too slow, the Node build step could be separated or made optional, since the core smoke test is the Python CLI path. However, including it validates the complete developer experience.
- **`pf init` inside the framework repo itself**: `pf init` is designed to initialize a consumer project that uses Pennyfarthing, not the framework repo itself. The CI job runs inside the pennyfarthing checkout, so `pf init` may behave differently than expected (the dist_root IS the repo). The init step may need to be `pf init --dist-root pennyfarthing-dist/` or equivalent, depending on how the CLI resolves paths.

## Acceptance Criteria

- New `fresh-clone-smoke` job exists in `pennyfarthing/.github/workflows/ci.yml`
- Job runs on every push to `develop`/`main` and on every PR (same triggers as existing jobs)
- `pf --version` exits 0 and prints a version string
- `pf init` completes without error in non-interactive mode
- `pf doctor --json` reports `"success": true` (no `"fail"` status checks)
- `pennyfarthing-dist/workflows/guided-tour/workflow.yaml` parses as valid YAML with expected structure (name, type, steps, gates)
- All 5 guided-tour step files (`step-01` through `step-05`) exist under `steps/`
- `pnpm install` and `pnpm run build` succeed on the fresh checkout
- Job does NOT depend on the `build` job (runs independently)
