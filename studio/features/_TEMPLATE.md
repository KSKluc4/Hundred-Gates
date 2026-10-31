---
id: F-XXX
title: <short name>
status: DRAFT            # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Planner       # who must act next: Planner | Auditor | Builder | Lucas
created: YYYY-MM-DD
updated: YYYY-MM-DD
depends_on: []           # e.g. [F-002, D-004]
pillars: []              # which PROJECT.md pillars this serves
---

# F-XXX — <title>

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
<What the player can do / feel after this ships.>

**Why now:** <Why this feature, why in this order.>

**Out of scope (explicitly):**
- <Thing someone might reasonably assume is included but isn't.>

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- Existing systems this touches: <files / scenes / modules>
- Relevant prior decisions: <D-### links>
- Relevant prior features: <F-### links>

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: <Option A name>
- **How it works:** <2–4 lines>
- **Why chosen:** <the deciding reasons>
- **Costs we're accepting:** <the downsides we know about and accept>
- **Would revisit if:** <the concrete signal that would make us reconsider>

### ❌ Rejected: <Option B name>
- **How it would work:** <1–2 lines>
- **Why rejected:** <specific reason — not "worse", say HOW it's worse>
- **Tempting because:** <why an implementer might drift toward it anyway>

### ❌ Rejected: <Option C name>
- **How it would work:**
- **Why rejected:**
- **Tempting because:**

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | <e.g. Movement must be frame-rate independent> | <e.g. D-003 fixed timestep> |
| C2 | | |

**Must not break:** <existing behaviors that must still work afterwards>

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1: <Given … when … then …>
- [ ] AC2:
- [ ] AC3:

**How to verify manually:** <what Lucas does in-game to confirm it works>

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | | | |
| T2 | | | |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed:** YYYY-MM-DD

Findings (severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion):

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-XXX-<slug>`

### Progress
- [ ] T1 — <commit hash when done>
- [ ] T2

### Deviations from plan
<Every place the code differs from §3–§6, with reason. "None" if none.>
- DEV-1: <what changed> — **Why:** <reason> — **Impact:** <what else this affects>

### Assumptions made (small, reversible)
- ASSUMPTION-1: <the gap in the spec> → <what I chose> — **Why:** <reason>

### Things the Auditor should look at closely
- <tricky spots, edge cases you're unsure about>

### How to test
<exact steps / commands / scene to run>

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed commit:** <hash>  ·  **Round:** 1

### Checklist
- [ ] Every AC in §5 met (state evidence per AC below)
- [ ] No Rejected option from §3 implemented, even partially
- [ ] All constraints in §4 and PROJECT.md respected
- [ ] Every deviation in §8 is justified; no undocumented deviations
- [ ] Assumptions in §8 are sane

### AC evidence
- AC1: ✅/❌ <where in the code / how verified>

### Findings
### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | | | yes/no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
