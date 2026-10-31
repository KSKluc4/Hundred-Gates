# The Studio — How This Project Is Run

One human, three AI roles, one shared source of truth.

| Role | Who | Owns | Never does |
|---|---|---|---|
| **Director** | Lucas | Vision, priorities, approval gates, final say | — |
| **Planner** | Claude (chat / Project) | Feature specs, options analysis, decisions | Writes production code |
| **Builder** | Claude Code | Implementation, implementation log, tests | Changes scope or re-opens rejected options silently |
| **Auditor** | Codex | Plan reviews, code reviews, verdicts | Edits code or the plan's decisions directly |

## Departments

The Planner role is split into **departments** (Direction, Combat & Bosses, more as phases
start). A department is a brief + a design doc, not a chat. Each feature has exactly one
owning department (`department:` in its header). See `studio/departments/README.md`.

```
studio/departments/   → one brief per department + roster and rules
studio/design/        → living design docs (source of truth per area)
studio/prompts/project-instructions.md → Claude Project instructions (replaces planner.md)
```

## The core rule: hand off files, never summaries

Context gets lost when one agent summarizes for the next. So nobody summarizes.
Every handoff is: **"Read `studio/features/F-XXX-name.md` and do your step."**
Each agent reads the *whole* file — including what was rejected and why — and
writes only into the sections it owns.

## The files

```
CLAUDE.md                 → Builder instructions (Claude Code auto-loads this)
AGENTS.md                 → Auditor instructions (Codex auto-loads this)
studio/
  README.md               → this file
  PROJECT.md              → vision, pillars, tech stack, global constraints (slow-changing)
  DECISIONS.md            → project-wide decision log (D-001, D-002…), incl. rejected options
  STATUS.md               → the board: what's in which stage right now
  GLOSSARY.md             → game terms with one meaning each (prevents drift between agents)
  features/
    _TEMPLATE.md          → feature spec template — the shared document
    F-001-*.md            → one file per feature, lives forever
  prompts/
    planner.md            → paste into a Claude Project as instructions
    handoffs.md           → copy-paste lines for every handoff
  new-feature.sh          → creates the next numbered feature file
```

## The pipeline

```
 idea ──► [1 PLAN] ──► [2 PLAN REVIEW] ──► ◆ GATE A ──► [3 BUILD] ──► [4 CODE REVIEW] ──► ◆ GATE B ──► DONE
          Planner       Auditor            Lucas        Builder       Auditor            Lucas
                          │                                              │
                          └── CHANGES_REQUESTED → back to Planner        └── CHANGES_REQUESTED → back to Builder
```

Status lives in the feature file's header **and** in `STATUS.md`.

| Status | Meaning | Next actor |
|---|---|---|
| `DRAFT` | Planner is writing | Planner |
| `PLAN_REVIEW` | Spec complete, awaiting audit | Auditor |
| `PLAN_CHANGES` | Auditor found blocking issues | Planner |
| `APPROVED` | Lucas signed off (Gate A) | Builder |
| `IN_PROGRESS` | Builder is implementing | Builder |
| `CODE_REVIEW` | Builder done, awaiting audit | Auditor |
| `CODE_CHANGES` | Auditor found blocking issues | Builder |
| `DONE` | Lucas signed off (Gate B) | — |
| `PARKED` | Shelved on purpose — keep the file, record why | Lucas |

**Only Lucas sets `APPROVED` and `DONE`.** Those are the boss gates.

## Section ownership in a feature file

| Section | Written by | Others may |
|---|---|---|
| 1–6 (Goal → Tasks) | Planner | Read only. Auditor comments in §7. |
| 7 Plan Review | Auditor | Planner replies inline under each finding |
| 8 Implementation Log | Builder | Read only |
| 9 Code Review | Auditor | Builder replies inline under each finding |
| 10 Open Questions | Anyone (append) | Lucas or Planner resolves |
| 11 Director Notes | Lucas | Everyone must obey |

## The ambiguity protocol (most important rule for the Builder)

When the spec doesn't answer something:

1. Check §3 **Rejected** — if the option you're about to pick is there, you can't pick it.
2. Check §4 **Constraints** and `PROJECT.md` — pick nothing that violates them.
3. Check `DECISIONS.md` — maybe it's already been decided project-wide.
4. If still ambiguous and the choice is **small and reversible** → pick the simplest option,
   log it in §8 as `ASSUMPTION:` with your reasoning, keep going.
5. If it's **large or hard to reverse** → write it in §10 Open Questions, stop that task,
   and tell Lucas.

Never silently re-adopt a rejected option. Never silently deviate from the plan.

## Decision IDs in code

When code does something non-obvious *because of* a decision, leave a pointer:

```gdscript
# D-007: fixed timestep, see studio/DECISIONS.md
```

That way the reasoning survives in the code, not just the docs.

## Weekly hygiene (10 min, Lucas)

- Move feature decisions that affect the whole game from feature files into `DECISIONS.md`.
- Clear resolved Open Questions.
- Update `STATUS.md`.
- Re-read `PROJECT.md` pillars. If a feature fights a pillar, kill the feature, not the pillar.
