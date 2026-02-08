# UX Designer Agent Patterns

<pattern name="component-spec">
Purpose → Variants (default/active/disabled/error) → States (idle/hover/focus/loading) → Accessibility (keyboard + screen reader).
</pattern>

<pattern name="collapsible-panel">
Collapsed panels: 20×60px expand button with vertical rotated label (`writing-mode: vertical-rl; transform: rotate(180deg)`). Same position as collapse button. Idle=muted, hover=accent.
</pattern>

<pattern name="cyclist-layout">
`#app-container` (flex row): file-panel → resize → diff-panel → resize → #main-content (message-view, tool-bar, editor) → #sidebar. Expand buttons absolute-positioned, visible when panels collapse.
</pattern>

<pattern name="message-width">
`.message-assistant p { max-width: 72ch }`. Use `max-width: min(72ch, 100%)` for responsive.
</pattern>
