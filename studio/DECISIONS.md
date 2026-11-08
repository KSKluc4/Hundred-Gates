# DECISIONS — Project-wide decision log

> Append-only. Never delete an entry — supersede it with a new one.
> A decision lives here if it affects more than one feature.
> Feature-only decisions stay in that feature's §3.

## Format

```
## D-### — <title>
- **Status:** PROPOSED | ACCEPTED | SUPERSEDED by D-###
- **Date:** YYYY-MM-DD · **Decided by:** Lucas (proposed by <role>)
- **Context:** <what forced the decision>
- **Chosen:** <option> — <why>
- **Rejected:**
  - <option> — <why not>
- **Consequences:** <what this locks in / makes harder>
- **Revisit if:** <signal>
```

---

## D-008 — Projectiles belong to their launcher; walls are reported by the glue
- **Status:** ACCEPTED
- **Date:** 2026-11-08 · **Decided by:** Lucas (proposed by Combat, from F-005; accepted at Gate A)
- **Context:** The caster (F-005) is the first ranged attack. Brute charges (F-006), bosses and
  the phase-2 archer will need the same two answers: where a projectile lives in the sim, and how
  core learns about walls without touching physics (G6).
- **Chosen:** A projectile is owned by the combatant that launched it (`ProjectileSet`), with
  identity = owner id + serial, snapshotted inside the owner, ordered by owner registration then
  serial. It's a 360° hitbox moving on the sim clock. Core plans every wall-bound move; the glue
  sweeps it against the `world` layer and reports the reached position. A reported position short
  of the plan by more than `DISTANCE_EPSILON` is a wall stop.
- **Rejected:**
  - *A combatant per projectile, registered at launch* — breaks fixed ids/order in snapshots
    (F-003/C19) and the reset. Tempting because the resolver handles it for free.
  - *Physics-node projectiles deciding hits* — hits from overlaps and the physics tick (G6, D-007).
    Tempting because it's the tutorial way.
  - *Wall geometry stored in core* — every level describes walls twice. Tempting because core
    tests could test walls.
- **Consequences:** Every hitbox reader uses `get_live_hitboxes()`. Wall stops are only known
  where Godot physics runs (the headless server has it). Projectiles die with their owner.
- **Revisit if:** a projectile must outlive its owner, or sweeps cost too much with many projectiles.

## D-007 — Combat runs on a shared step grid
- **Status:** ACCEPTED
- **Date:** 2026-11-01 · **Decided by:** Lucas (proposed by Combat, from the F-003 plan review)
- **Context:** Hits depend on exact timing: the vulnerable dash tail (F-001/C8), short active
  phases, and hitstop on separate entity clocks. Testing hits once per physics tick gives
  different results at different tick rates, which breaks G1 and would desync co-op later.
- **Chosen:** Each physics tick splits into equal combat steps of at most
  `1 / combat_step_rate` (default 120 Hz, data, must be a multiple of 120). Every combatant
  advances, bodies move, and hits are decided at the end of each step, so 30, 60 and 120
  ticks/s share the same instants. Details: F-003 C15.
- **Rejected:**
  - *Resolve once per physics tick* — the result depends on the tick rate, and a short
    active phase can vanish. Tempting because it's the simplest loop.
  - *Solve exact contact times inside a tick* — a hit changes the rest of the tick, so it
    needs rollback and swept collision, for precision nobody can feel. Tempting because it
    sounds like the purest reading of "exact time".
  - *Force the whole game to 120 physics ticks/s* — G1 still has to hold, and physics would
    cost more for every scene. Tempting because no sub-steps would be needed.
- **Consequences:** Hit timing is quantized to 1/120 s. `move_and_slide()` runs several
  times per physics tick. Every entity that fights must implement `Combatant` and advance by
  steps. Enemies and bosses (F-004 on) inherit this.
- **Revisit if:** Sub-stepping costs too much with many enemies, or phase 3 networking needs
  a different simulation rate.

## D-006 — Death and re-entry (phases 1–2)
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (proposed by Combat, promoted by Direction)
- **Context:** Combat CQ6. How death works shapes floor design, item economy, saves and
  co-op later, so it's a project-wide rule, not a combat detail.
- **Chosen:** On death the character returns to town. Floors already cleared stay cleared.
  Once a character has reached a floor's boss room, it may re-enter that floor directly at
  the boss. Phase 1 keeps all loot. Progress is tracked **per character** (D-005).
- **Rejected:**
  - *Restart the whole floor on death* — trains the hallway, not the boss; slows learning
    boss patterns (pillar 2). Tempting because it feels fair and is simple.
  - *Permadeath (die in game = character deleted, SAO-style)* — with class-locked
    characters (D-005) and 100 floors, one mistake would erase dozens of hours. Tempting
    because it's the source theme and creates real tension. Could return later as an
    optional hardcore mode.
- **Consequences:** Save data (G7, phase 2) needs per-character "floors cleared" and
  "boss rooms reached". Co-op (phase 3) needs a party re-entry rule. Items & Economy may
  add loot/currency loss on death in phase 2 (Combat CX3).
- **Revisit if:** The boss shortcut makes players skip dungeon content, or deaths stop
  feeling like they matter.

## D-005 — Class model: fixed class per character, bound to a weapon family
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (options framed by Direction)
- **Context:** Lucas wants multiple classes (warrior, healer, archer, assassin…). The class
  model shapes combat, progression, saves and guild play, so it's decided before combat design.
- **Chosen:** Each character has **one fixed class**, chosen at creation. Changing class means
  creating a new character from scratch. Each class is **bound to its weapon family**
  (warrior → sword, archer → bow…): the weapon defines the playstyle, but a character can only
  equip weapons of its class family. Classes are **data** (`data/classes/*.tres`: weapon
  family, base stats, skills) per G9 — adding a class means adding data + art, not rewriting
  the player.
- **Phasing:** P1 = one class. P2 = +2 solo-viable classes. P3 = healer/support, together with
  co-op (a healer has no job solo). P4+ = more classes/specializations for guild raids.
- **Rejected:**
  - *Free weapon swap, weapon = class at any moment* — loses character identity and the
    group-composition layer guilds need. Tempting because it's flexible and cheaper to build.
  - *Hybrid: fixed role + free weapon within role* — two systems to design and balance at
    once; too much for a one-person studio. Tempting because of build depth.
- **Consequences:** Save system must support multiple character slots (G7, phase 2). Art and
  animation cost multiplies per class. Every boss must be beatable solo by every
  solo-viable class. A healer arriving in P3 means P1–P2 balance assumes no healing from allies.
- **Revisit if:** Playtests show players abandoning characters because they want to switch class.

## D-004 — Lint/format tooling: gdtoolkit
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (proposed by Planner, raised by Auditor in F-000 §7)
- **Context:** Two different agents write and review GDScript. Without enforced style,
  diffs fill with formatting noise and naming drifts from GLOSSARY.md.
- **Chosen:** gdtoolkit (`gdlint`, `gdformat`), 4.x line (matches Godot 4), exact version
  pinned in `requirements-dev.txt`, installed into a project-local `.venv` by
  `tools/setup`. Dev-only — never shipped with the game.
- **Rejected:**
  - *No linter, Godot editor warnings only* — catches typing issues but not formatting or
    naming, and isn't a CLI pass/fail an agent can run. Tempting because zero setup.
    (Editor warnings stay on anyway.)
  - *Global `pip install` without venv* — pollutes system Python, versions drift between
    Lucas's Mac and agent machines. Tempting because one command shorter.
- **Consequences:** Python 3 required on dev machines (present on macOS with Xcode CLT).
- **Revisit if:** gdtoolkit lags behind a Godot 4.x syntax we need, or is unmaintained.

## D-003 — Test framework: GUT, vendored
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (proposed by Planner, raised by Auditor in F-000 §7)
- **Context:** `src/core/` logic (G6) must be unit-testable from day one, and agents need a
  headless pass/fail signal.
- **Chosen:** GUT (Godot Unit Test), release compatible with the pinned Godot 4 version,
  vendored (committed) into `addons/gut/`. Version recorded in `README.md`. Run headless
  via `tools/test`.
- **Rejected:**
  - *gdUnit4* — richer assertions and scene runner, C# support we don't need; more
    surface than phase 1 needs. Tempting because of better scene testing.
  - *No framework yet* — core code would accumulate untested. Tempting because "nothing
    to test yet".
  - *GUT as git submodule* — clone needs `--recursive`, agents and fresh clones forget it,
    tests silently missing. Tempting because the repo stays smaller.
- **Consequences:** Updating GUT = replacing the folder in a dedicated commit.
- **Revisit if:** We need scene/input simulation tests GUT can't do cleanly.

## D-002 — Build in phases: offline first, online-ready architecture
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (proposed by Planner)
- **Context:** The vision is an online 100-floor tower RPG with guilds and a player
  market. Built all at once, a solo dev never reaches a playable game.
- **Chosen:** 5 phases (see PROJECT.md roadmap). Phases 1–2 are offline single-player,
  but code follows G6–G9 from day one so co-op/online can be added without a rewrite.
- **Rejected:**
  - *Online from day one* — netcode, servers and accounts would eat months before the
    first fun fight exists; nothing to test if combat is good. Tempting because "it's
    an online game, so start online".
  - *Offline with no online prep* — fastest start, but adding multiplayer to logic
    tangled with rendering and input usually means a full rewrite. Tempting because
    G6–G9 feel like overhead in phase 1.
- **Consequences:** Phase 1 is slightly slower (command layer, data files, serializable
  state). Engine choice (D-001) must have a viable multiplayer path.
- **Revisit if:** Phase 1 combat isn't fun after 2 iterations — then the problem is the
  core game, not the architecture, and online plans pause.

## D-001 — Engine and language
- **Status:** ACCEPTED
- **Date:** 2026-10-31 · **Decided by:** Lucas (proposed by Planner)
- **Context:** Nothing can be built before this. Requirements, in order:
  1. Strong 2D, top-down friendly.
  2. Viable multiplayer path for phases 3–4 (D-002): headless/dedicated server possible.
  3. Works well with AI agents: project/scene files are plain text and diff cleanly,
     so Claude Code can write them and Codex can review them.
  4. Free, no revenue-share surprises on a long project.
  5. Compatible with what the NoNe Class course teaches (pending: which engine?).
- **Proposed:** Godot 4 + GDScript.
  - 2D is first-class (tilemaps, collision, animation, not a 3D engine pretending).
  - Scenes (`.tscn`) and resources (`.tres`) are readable text → agents can edit and
    review everything, not just scripts.
  - Built-in high-level multiplayer API (RPCs, sync, authority) and headless server
    export → covers phase 3, and phase 4 game server. Accounts/guilds/market backend
    can be a separate web API (Node/Express or similar).
  - MIT licence, free forever. Small and fast to open.
  - Data-driven content (G9) fits naturally via custom `Resource` types.
- **Options considered:**
  - *Unity (C#)* — biggest ecosystem and multiplayer libraries (Netcode, Mirror,
    Fish-Net). Rejected because: scenes/prefabs are noisy YAML that agents edit badly,
    heavy editor, 2D is secondary, and licensing changes have hurt trust before.
    Tempting because of the tutorials and asset store volume.
  - *Phaser + TypeScript (custom engine-ish)* — Lucas already knows TS; client and Node
    server could share the same game-logic code (great for G6). Rejected because: no
    editor, so tilemaps, animation and tooling must be built or glued together — months
    spent on tools instead of the game. Tempting because of the shared-code server.
  - *Godot with C#* — stronger typing, Lucas knows C-family languages. Not chosen
    because GDScript has far more 2D examples/docs and tighter editor integration;
    C# web export is limited. Could be revisited per-module later.
- **Consequences:** Team learns GDScript (Python-like, fast to pick up). Multiplayer is
  built on Godot's networking; very large player counts (true MMO scale) would need
  custom server work in phase 4+.
- **Revisit if:** NoNe Class teaches a different engine and its art/animation workflow
  depends on it, or a phase-1 prototype hits a hard Godot limitation.
