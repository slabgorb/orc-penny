# architect decisions

<decision id="DEC-ARCH-001" date="2026-06-03" story="154-1">
**Portrait resolution order: override → local bundled → R2 CDN → legacy (LFS/cyclist).**
CDN is the new *primary* remote source, so it sits ABOVE legacy fallbacks (deviates from issue #17's "lowest priority" wording — code is correct, spec updated). Legacy LFS/cyclist fallbacks MUST stay until R2 coverage is confirmed for ALL themes — rollout is incomplete (~28 themes unrendered as of this date), so removing them would blank portraits for un-uploaded themes. Full legacy deprecation is a future story gated on complete R2 coverage.
</decision>

<decision id="DEC-ARCH-002" date="2026-06-24" story="159-8">
**Frame liveness signal must be traffic, not a launching-process PID.** 161-1's self-termination
killed live sessions because `start_frame()` recorded `os.getpid()` of its caller as owner — fine
on the `pf frame start` exec path (PID preserved via execvpe), broken on the SessionStart-hook and
`pf launch` auto-start paths (caller is ephemeral → dead/recycled PID → ~30s self-kill, "random" via
PID reuse). Plus idle-timeout ignored OTLP/HTTP traffic (only WS connect/disconnect touched activity).
Decision (ADR-0040): make inbound OTLP/HTTP traffic the primary reuse-proof liveness signal; demote
owner-PID to an optional identity-verified fast-path (or drop it); shorten idle window; log shutdown
reason. **Liveness contract:** self-terminate iff NO session uses the frame, where "uses" = a WS
client OR recent traffic OR a verified-alive owning session. Coordinate with 159-5 (hardens the SAME
monitor against silent death) — 159-8 lands first or together, else 159-5 makes the random-death MORE
reliable. The graceful-`Shutting down` log line (not OOM) is the tell that it's self-termination.
</decision>
