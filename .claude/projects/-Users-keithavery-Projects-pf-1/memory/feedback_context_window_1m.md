---
name: Context window is 1M tokens, not 200k
description: Opus 4.6 has 1M context — the old 200k default causes false critical warnings every session
type: feedback
---

The context_window.py default was `max_tokens: int = 200000`. Changed to 1000000. This caused false "CRITICAL 91%" warnings that made agents panic and rush handoffs when we were only at ~18% of actual capacity.

**Why:** User runs Opus 4.6 with 1M context. The 200k default meant warnings fired at 180k tokens — barely into the session. Every session hit this and agents would rush, skip steps, or refuse to continue.

**How to apply:** The default is now 1M. The proper fix is to detect the model from the transcript and set max_tokens dynamically — that's a future story, not done yet. For now the 1M default stops the bleeding.
