# architect decisions

<decision id="DEC-ARCH-001" date="2026-06-03" story="154-1">
**Portrait resolution order: override → local bundled → R2 CDN → legacy (LFS/cyclist).**
CDN is the new *primary* remote source, so it sits ABOVE legacy fallbacks (deviates from issue #17's "lowest priority" wording — code is correct, spec updated). Legacy LFS/cyclist fallbacks MUST stay until R2 coverage is confirmed for ALL themes — rollout is incomplete (~28 themes unrendered as of this date), so removing them would blank portraits for un-uploaded themes. Full legacy deprecation is a future story gated on complete R2 coverage.
</decision>
