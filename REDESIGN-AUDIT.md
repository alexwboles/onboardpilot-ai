# REDESIGN-AUDIT — onboardpilot-ai (2026-10-13)

Employee onboarding checklists: dashboard, new-hire intake, buddy system,
role templates, manager notes, first-30-day pulse, welcome drafts.
Already feature-complete; the gap is visual identity + BambooHR-grade task rigor.

## Competitors referenced
- **BambooHR** — onboarding checklists grouped by phase (Before First Day / First
  Day / First Week / First Month); every task has checkbox + title + **due date** +
  assignee; progress bar per employee; warm people-first design; preboarding.
- **Rippling** — 30-60-90 day framework, week-by-week checklists, milestone
  reviews, manager 1:1 structure.

## Gaps found (visual / functional / flow)

### Functional
1. **Tasks have no due dates.** BambooHR's signature is per-task due dates with
   overdue states. Here "overdue" is a blunt phase-level flag ("Day-1 items
   overdue") — no per-task date, no real overdue sort signal.
2. No per-task due-date display anywhere in the checklist.

### Visual
3. Generic cream/red tabbed app — reads as a template, not HR software.
   BambooHR reads warm, human, people-first: soft cream, deep green, friendly
   avatars, journey progress.
4. Hire cards are flat; no progress ring, no journey feel. The "journey" station
   strip exists but is visually weak.
5. Task rows are plain; owners are raw selects, no visual owner pills.

### Flow
6. Dashboard → hire detail works; keep. The buddy-check-in nudge panel is good —
   keep and style.

## Redesign plan
- **Identity: "The welcome desk."** Deep forest-green sidebar (#1e4633), warm cream
  paper workspace, gold secondary accent. Humanist type, sharp edges.
- **Per-task due dates** (new): Day 1 → start date, Week 1 → start + 6 days,
  Day 30 → start + 29 days. Shown as date chips; overdue tasks get red flags;
  dashboard overdue sort uses real per-task dates.
- **Journey timeline** restyled as a real path: connected stations, current-station
  marker, per-phase counts.
- **Hire cards**: avatar initials, SVG progress ring, phase mini-bars, next
  milestone line (keep existing data).
- **Task rows**: due-date chip, owner pill, guidance text; overdue highlighting.
- Sidebar shell (brand, vertical nav, local pill) consistent with batch pattern but
  with the forest-green identity.
- Preserve: all views, notes, pulse, buddies, roles, settings, CSV export, print.

## Non-goals
- Custom phase definitions (BambooHR power feature; out of scope).
- True 30-60-90 milestone reviews (pulse check-ins already cover the need).
