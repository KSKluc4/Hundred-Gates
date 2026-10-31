# Handoff lines — copy, swap F-XXX, paste

The rule: **point at the file, never summarize it.**

---

### 1 · New feature → Planner (Claude chat, inside the Planner Project)
```
New feature idea: <your idea, raw, as messy as you want>.
Next free ID is F-XXX. Ask me what you need, then write the spec.
```
Then: run `./studio/new-feature.sh <slug>` and paste the Planner's output into the file it creates. Commit.

### 2 · Plan → Auditor (Codex)
```
Audit plan studio/features/F-XXX-<slug>.md in Mode A (Plan Review) per AGENTS.md.
```

### 2b · Plan changes → back to Planner (Claude chat)
```
Auditor requested changes on F-XXX. Here's §7:
<paste §7>
Reply to each finding and give me the full updated file.
```

### ◆ Gate A — you approve
Read the file. Edit the header: `status: APPROVED`, `owner_now: Builder`. Add anything to §11. Update STATUS.md. Commit.

### 3 · Build → Builder (Claude Code)
```
Implement studio/features/F-XXX-<slug>.md per CLAUDE.md.
```

### 4 · Code → Auditor (Codex)
```
Review branch feature/F-XXX-<slug> against studio/features/F-XXX-<slug>.md in Mode B (Code Review) per AGENTS.md.
```

### 4b · Code changes → Builder (Claude Code)
```
F-XXX is CODE_CHANGES. Address §9 round <n> per CLAUDE.md.
```

### ◆ Gate B — you sign off
Play it. Check §5 "How to verify manually". If good: merge branch, set `status: DONE`, update STATUS.md, move any cross-feature decisions into DECISIONS.md.

---

## Escape hatches

- **Builder blocked on an Open Question** → take §10 to the Planner chat, get an answer, write it in §10's Answer column (and §11 if it's an override). Tell Builder: `F-XXX Q<n> answered, continue.`
- **Builder and Auditor disagree after 2 rounds** → you decide. Write the call in §11. That ends it.
- **Plan turns out wrong mid-build** → Builder stops, logs it in §10. Feature goes back to `DRAFT`, Planner revises. Don't let the Builder redesign on the fly.
