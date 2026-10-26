# Attendrix teacher dashboard design system

This is a documentation layer for the active React + TypeScript + Vite dashboard. The current application keeps its existing layout and token set; no component should imply a backend capability that is not present.

## Visual foundation

| Token / concern | Current convention |
|---|---|
| Primary text / deep surface | `--ink: #122631` |
| Muted text | `--muted: #687a7a` |
| Borders | `--line: #dce6e3` |
| Paper | `--paper: #fff` |
| Primary action / verified scene accent | `--teal: #087f74`, dark `#075e57` |
| Review / pending | amber `#c77c13` on `#fff1d8` |
| Information | blue `#2768aa` on `#e8f2fe` |
| Secondary category | violet `#6559a9` on `#eeeafd` |
| Absent / error | coral `#b44d45` on `#fde7e4` |
| Elevation | restrained `--shadow: 0 18px 40px rgba(18,38,49,.07)` |
| Typography | Manrope for interface text; DM Mono for short identifiers and codes |

Use neutral surfaces and borders, clear section headings, restrained semantic status colors, and short actionable labels. Color must not be the only way to communicate state. Do not add decorative charts or AI activity indicators without a supporting endpoint and data definition.

## Layout and spacing

- Desktop shell: fixed 252px navigation rail; content area is centered with a maximum width of 1270px.
- Standard page padding: approximately 38px vertical and 42px horizontal; compact to 12px inside the session workspace on narrow screens.
- Cards and panels use a 1px border, white surface, and approximately 11px corner radius. Reuse the existing `.panel`, `.metric-card`, `.flow-panel`, and button variants before introducing new primitives.
- Teacher workflows prioritize current session actions, session review, roster corrections, then reporting. A review inbox is scoped to the selected session because no cross-session queue endpoint exists.
- Breakpoint at 720px collapses multi-column flows to a single column and wraps dense session rows. Keep focusable controls visible and avoid horizontal overflow.

## Component and interaction conventions

- Primary buttons perform the principal next action; secondary buttons refresh, navigate, or perform reversible/secondary actions.
- Loading, unavailable, error, empty, and loaded-zero are distinct states. Keep stale data visible only when labeled with its last successful refresh time and a refresh error.
- Required reasons for review/correction are captured in a labeled form and sent to the backend's audited action. Consequential finalization remains confirmed.
- Refreshing session data is an explicit user action with a visible timestamp; periodic refresh and WebSocket messages trigger authoritative API re-fetches, not local synthetic updates.
- Reports are session-scoped. Label print/save-to-PDF as browser printing; the API returns HTML and does not render a PDF.

## Status semantics and non-claims

- Session states come from the API: scheduled, open, closed, finalized. Missing states display as unavailable, never as scheduled/open by default.
- Attendance states come from API rows: present, absent, pending. Do not infer a verified identity from present status.
- Submission states are the actual backend values (`VERIFIED`, `NEEDS_REVIEW`, `REJECTED`) and professor decisions. `VERIFIED` is only a configured scene-evidence outcome for an authenticated submitter.
- Person counts, quality checks, explanation, and optional configured-region detection can be displayed when returned. Missing values display as unknown/unavailable, not zero or false.
- The backend does not implement facial identity match, liveness, teacher identity/presence, classroom identity, screen-spoof detection, secondary analysis, job queue/worker monitoring, or calibrated model confidence. Do not create UI claims, scores, or analytics for them.

## Accessibility

- Provide visible keyboard focus using the existing `:focus-visible` treatment; every form control has a programmatic label.
- Use `role="alert"` for actionable errors and `role="status"` for nonurgent updates. Button labels describe the target/action, not just an icon.
- Keep status text readable at ordinary body size; do not use color alone to distinguish outcomes.
- Respect reduced-motion preferences for any future animation; current transitions remain short and ornamental only.
