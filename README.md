# OnboardPilot AI ✈️

Employee onboarding checklists for small businesses. Pick a role, add a new hire, and get a ready-made Day 1 / Week 1 / Day 30 checklist — track progress, assign a buddy, and draft a welcome message.

## What it does

- **Role-based checklists** — 6 built-in role templates (Retail Associate, Line Cook, Barista, Front Desk, Warehouse Associate, Office Admin). Each generates a checklist across three phases: **Day 1**, **Week 1**, and **Day 30**, with task categories (Paperwork / Training / Culture / Tools) and owner hints (Manager / Buddy / New hire).
- **Generic document checklist** — every Day-1 template includes document items: government ID, tax withholding form (labeled e.g. W-4 in the US), direct deposit / payroll form, and emergency contact details.
- **Per-hire progress tracking** — each hire gets their own checklist instance. Completion % is computed overall and per phase. The dashboard lists all hires with progress bars, flags **overdue Day-1 items** (past the hire's start date), and offers a per-hire detail view.
- **Buddy / mentor assignment** — keep a buddy list (name + role), assign one buddy per hire; the buddy shows on the hire's dashboard.
- **Custom roles & tasks** — create your own roles with your own tasks per phase, all stored locally.
- **Draft welcome message** — one click drafts a welcome note for a hire. Works out of the box with a local template; if you save an OpenAI API key in Settings, it uses the OpenAI API instead (optional, never required).

## How to run

Just open `index.html` in any modern browser. No build step, no server, no dependencies.

```bash
open index.html   # or double-click it
```

## Data & privacy

All data (hires, buddies, custom roles, settings) stays in **this browser's localStorage** under the key `onboardpilot_v1`. Nothing is sent to any server — the only exception is the optional OpenAI API call, which only happens if you explicitly save an API key.

## Tests

```bash
bash test/smoke.sh   # 15 checks: files, syntax, logic assertions
bash test/e2e.sh     # 6 end-to-end flows (Node, no network)
```

## Disclaimer — document checklist

The document checklist (ID, tax withholding, payroll, emergency contact) is **generic guidance only — not legal or tax advice**. Requirements vary by country, state, and locality. **Check your local rules** (and talk to a qualified professional) before relying on it for compliance.

## Optional OpenAI key

Settings → paste your OpenAI API key → it is stored only in localStorage on your machine. "Draft welcome message" then calls the OpenAI API (`gpt-4o-mini`) for an AI-written note. Without a key, a friendly local template is used and the app works fully offline. The automated tests never touch the network path.
