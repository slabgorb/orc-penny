# Installer Issues

<issue id="1" severity="low">
**postinstall error on fresh install.** `pennyfarthing update` fails with "not initialized". `|| true` swallows it. Guard with init check.
</issue>

<issue id="2" severity="high">
**EEXIST crash on settings.local.json.** Init creates symlink but existing regular file blocks it. Should detect, back up, then symlink.
</issue>

<issue id="3" severity="medium">
**Hooks not executable after init.** npm install doesn't preserve +x. `init` should `chmod +x` all `.sh` in `.pennyfarthing/scripts/hooks/`, not just doctor-known hooks.
</issue>

<issue id="4" severity="low">
**No guidance on cloning framework repo.** Orchestrator expects inlined `pennyfarthing/` but doesn't document the clone step.
</issue>

<issue id="5" severity="high">
**`config.local.yaml` not created by init.** Controls theme, workflow settings. Without it, theme resolution fails silently. Init should generate defaults.
</issue>

<issue id="6" severity="medium">
**`setup-env.sh` hook referenced but missing.** settings.local.json references it but init doesn't create it. Hook fails silently on session start.
</issue>
