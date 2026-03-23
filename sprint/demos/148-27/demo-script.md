**Total runtime: ~4 minutes**

---

**Scene 1 — Title (Slide 1) | 0:00–0:20**
Open on the title slide. "Today we're showing a small but meaningful quality-of-life improvement to team workflows."

---

**Scene 2 — Problem (Slide 2) | 0:20–0:50**
Reference the problem slide. "Every time someone ran a peloton team session, they had to specify how they wanted their panes arranged. If they forgot — or just didn't want to type it — they got whatever the default was. That preference couldn't be saved anywhere."

---

**Scene 3 — What We Built (Slide 3) | 0:50–1:30**
Open the TUI settings page live:
```bash
pf settings
```
Navigate to the **Peloton** group. Show the **Peloton Layout** dropdown with three options: Grid, Vertical, Horizontal. Select **Grid**. "This choice is now written to `config.local.yaml` and respected every time a peloton session starts."

*Fallback if terminal unavailable:* Show the Before/After slide with a screenshot of the settings page with and without the dropdown present.

---

**Scene 4 — Why This Approach (Slide 4) | 1:30–2:00**
Reference the approach slide. "Eleven lines of code. The layout engine already knew how to read this value — we just gave users a way to set it without touching config files directly."

---

**Scene 5 — Before/After (optional slide) | 2:00–2:30**
Show the before state: "Previously, to get a grid layout you'd have to pass `--layout grid` on every invocation, or edit the YAML file manually."
Show the after state: "Now it's a one-time setting, remembered forever."

---

**Scene 6 — Roadmap (Roadmap slide) | 2:30–3:15**
"This is one of several TUI improvements in the current sprint. The settings page is growing into a real control surface — not just a config file workaround."

---

**Scene 7 — Questions | 3:15–4:00**
Open floor.

---