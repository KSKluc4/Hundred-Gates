# Departments

A department is a **document, not a chat**. Chats are disposable — the brief and the
design doc are the department's memory. Start a fresh chat per feature or topic.

## Roster

| Department | Brief | Design doc | Active since | Owns |
|---|---|---|---|---|
| Direction | `direction.md` | `PROJECT.md`, `DECISIONS.md` | Phase 1 | Vision, priorities, cross-area specs, final spec check |
| Combat & Bosses | `combat.md` | `../design/combat.md` | Phase 1 | Player combat, enemies, boss patterns, combat tunables |

Planned (create when their phase starts — not before):

| Department | Starts | Owns |
|---|---|---|
| Art & Game Feel | When art style is set (Q1 in F-000) | Sprites, animation, juice, resolution, palette |
| Floors & Level Design | Phase 2 | Floor/room structure, generation, pacing across floors |
| Items & Economy | Phase 2 | Gear, upgrades, NPC shop, drop rates |
| Network | Phase 3 | Co-op, sync, authority |
| Backend | Phase 4 | Accounts, guilds, market, persistence |
| Lore | When useful | World, tower story, NPC writing |

## How to activate a department

In a new chat inside the "2D de Jogo" Claude Project:

```
Você é o departamento de <Nome> do Hundred Gates. Lê studio/departments/<arquivo>.md e segue.
<o que você quer>
```

## Rules

1. **One owner per feature.** Every feature file has `department:` in its header.
   Only that department writes §1–§6.
2. **Cross-department needs go through §10 Open Questions**, tagged `→ <Department>`.
   Lucas carries the question to that department's chat and pastes the answer back.
3. **Design docs are the source of truth for their area.** A spec that contradicts its
   department's design doc is wrong — fix one of them, explicitly.
4. **Departments propose, Lucas decides.** Departments may propose D-### entries;
   only Lucas marks them ACCEPTED.
5. **Direction reviews every spec before it goes to the Auditor** — a 2-minute check that
   it fits the pillars, the phase, and doesn't collide with another department.
6. **After a chat produces something durable**, it ends with the exact updated design-doc
   section for Lucas to commit. If it isn't in the repo, it didn't happen.
