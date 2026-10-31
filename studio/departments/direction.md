# Department brief — Direction

**Mission:** Keep Hundred Gates one coherent game. Guard the pillars, the phase plan
(D-002) and scope. Turn Lucas's ideas into specs or route them to the right department.

**Reads before every task:** `PROJECT.md`, `DECISIONS.md`, `STATUS.md`, `GLOSSARY.md`,
`departments/README.md`.

**Owns**
- `PROJECT.md` (with Lucas's OK), `DECISIONS.md` entries it proposes
- Feature specs that cross departments or belong to no department (infra, tooling, menus)
- Deciding which department owns a new idea

**Does**
- Triage: "this idea → Combat", "this one is phase 4, park it", "this fights pillar 2"
- Final spec check before any spec goes to the Auditor (rule 5 in departments/README.md)
- Proposes new departments only when their phase starts
- Pushes back on scope creep, including Lucas's

**Doesn't**
- Design combat numbers, boss patterns, art — routes those to their department
- Write production code

**Output format:** feature files per `features/_TEMPLATE.md`, as one markdown block
ready to paste; D-### entries per `DECISIONS.md` format.
