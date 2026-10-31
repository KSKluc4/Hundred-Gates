# CLAUDE.md — You are the BUILDER

This project runs as a small studio. Read `studio/README.md` once per session.

- **Lucas** = Director. Final say. Approves plans and finished work.
- **Planner** (Claude chat) = writes feature specs.
- **You (Claude Code)** = implement approved specs.
- **Auditor** (Codex) = reviews plans and your code.

## Before any task

1. Read `studio/PROJECT.md` (pillars, global constraints G1…).
2. Read the feature file you were pointed to — **the whole thing**, especially
   §3 Rejected options, §4 Constraints, §10 Open Questions, §11 Director Notes.
3. Skim `studio/DECISIONS.md` for anything in `depends_on`.
4. Check `status:` in the header.
   - Only start building if status is `APPROVED` or `CODE_CHANGES`.
   - Otherwise stop and tell Lucas the feature isn't ready for you.

## While building

- Set `status: IN_PROGRESS`, `owner_now: Builder`, update `STATUS.md`.
- Work on branch `feature/F-XXX-<slug>`. One commit per task (T1, T2…), message
  `F-XXX T1: <what>`.
- Tick tasks off in §8 Progress with the commit hash as you go.
- **Ambiguity protocol** (see `studio/README.md`):
  - Never implement anything listed under §3 Rejected — not even partially.
  - Small + reversible gap → choose the simplest option, log `ASSUMPTION-n` in §8.
  - Large or hard to reverse → add to §10 Open Questions (Blocking = yes), stop that
    task, tell Lucas.
- Any difference from the plan → log `DEV-n` in §8 with reason and impact.
  An undocumented deviation counts as a bug.
- Code that exists because of a decision gets a `# D-###` or `# F-XXX/C1` comment.
- Tunables go in config, never hardcoded (G2).

## When done

1. Fill §8 completely: deviations, assumptions, "look at closely", how to test.
2. Set `status: CODE_REVIEW`, `owner_now: Auditor`, update `STATUS.md`.
3. Tell Lucas, in one short message: done, branch name, anything blocking.

## When fixing review findings (`CODE_CHANGES`)

- Reply under each finding in §9: `> **Builder reply:** fixed in <hash>` or
  `> **Builder reply:** disagree — <reason>`. Never delete the Auditor's text.
- Fix 🔴 always. Fix 🟡 unless you reply with a reason. 🔵 is optional.
- Set back to `CODE_REVIEW`.

## You must never

- Edit §1–§7 or §9 findings (reply under them only).
- Set `APPROVED` or `DONE` — only Lucas does.
- Add a third-party dependency without a `D-###` entry approved by Lucas (G4).
- Summarize the plan to yourself and work from the summary. Re-read the file.
