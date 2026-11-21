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

## D-016 — Slice 3 is several features cut from `main`, built as D-013 and D-014 set
- **Status:** ACCEPTED
- **Date:** 2026-11-20 · **Decided by:** Lucas (instruction in chat)
- **Context:** With F-011 to F-014 done and merged, Lucas answered "Yes, start" to "Start slice
  3 now?". Slice 3 is the phase 1 finish from the lead's plan of 2026-11-18: basic loot and
  equip, title, pause and death screens, a dash tutorial, sprites, audio, export builds and the
  outside playtest. That is too much for one feature, and parts of it are Lucas's own work
  (art, audio, choosing the playtester). Asked which part comes first, he chose "Menus +
  tutorial", then split the tutorial off: "No tutorial yet create kind like a new slice for
  tutorial only". D-011, D-013 and D-015 cover F-011 to F-014 only.
- **Chosen:** Slice 3 is built as one feature per part, each on its own branch cut from `main`
  (nothing waits in review, so nothing is stacked). The first is F-015 "Menus". The tutorial is
  its own later feature. For each part the lead first brings Lucas the decisions that are his;
  his answers and go-ahead in chat are Gate A, so the file skips `APPROVED`. The rest is as
  D-013 and D-014 set: the lead writes the spec, a plan review by fresh reviewers runs before
  any code, up to two Sonnet implementers write on disjoint file lists, only the lead gates
  and commits, the lead runs the code review, and Lucas's playtest is Gate B.
- **Rejected:**
  - *One feature for the whole slice* — one spec and one review for seven unrelated parts, and
    nothing could be played until all were done. Tempting because slices 1 and 2 were one
    feature each.
  - *Keep stacking branches* — only needed while the feature below is unmerged. Tempting
    because it is what the last four features did.
  - *Tutorial inside the menus feature* — Lucas split it off. Tempting because both are "what a
    stranger needs in the first minute".
- **Consequences:** The order of the remaining parts (tutorial, loot, export, sprites, audio,
  playtest) is Lucas's to set, one at a time. Loot needs the Items & Economy department opened
  and a design; sprites need the art style and pixel scale decision that `PHASE1.md` lists as
  owed. `PHASE1.md`'s rows are still out of date (Direction's file).
- **Added 2026-11-21 (Lucas, in chat):** the tutorial is built after every other part that
  changes what the player does or sees, so it teaches the game as it is: "tutorial you need to
  have all the features done before". It comes after loot, sprites and audio; the order of
  those is still his to set. After playing F-015 he added: "later on we gonna work on make it
  beautifull but first focus on making sure is working". The lead reads this as: the parts
  that add or prove function (loot, export builds) come before the parts that change looks
  and sound (sprites, audio). That reading is the lead's, not his words.
- **Revisit if:** two parts turn out to need each other's code before either can be played.


## D-015 — Gate B fixes that are new work get their own stacked feature, built as D-013 sets
- **Status:** ACCEPTED
- **Date:** 2026-11-19 · **Decided by:** Lucas (instruction in chat)
- **Context:** At Gate B of F-011 and F-012 Lucas raised six points and wrote: "Let's fix this
  before we move on with the slices. do 2 fixes at a time no more than that". The first pair
  were defects and were fixed inside F-011 and F-012. The second pair (a follow camera with
  rooms larger than the screen; a dash recovery) and the third (waves) are new behaviour that
  touch several features and two departments. On the lead's proposal for the second pair he
  answered: "I liked all the idea for the rooms and for the dash just a short end-lag yeah so
  go ahead with that".
- **Chosen:** Each such pair is one new feature, stacked on the branch that holds the work it
  changes (F-013 on `feature/F-012-the-loop`). D-013's arrangement applies: the lead writes
  the spec, up to two Sonnet implementers write on disjoint file lists, only the lead gates
  and commits. Lucas's go-ahead in chat on the lead's written proposal is Gate A, so the file
  skips `APPROVED`. The plan review and the code review run as D-014 sets. A feature may cover
  two departments when the pair does; the header names both.
- **Rejected:**
  - *Keep adding to F-011 and F-012* — their specs, logs and reviews would describe a
    different game from the one they approved, and F-001's dash is `DONE`. Tempting because
    no new file or branch is needed.
  - *One feature per fix* — two specs and four reviews for changes Lucas asked to judge
    together. Tempting because each feature would have one department.
- **Consequences:** The stack grows: F-011, then F-012, then F-013, merged in that order.
  `PHASE1.md` uses the ids F-013 to F-016 for planned features that have not started; its rows
  need renumbering (Direction). Lucas plays the top of the stack.
- **Revisit if:** a stacked feature has to change after the one below it is merged.


## D-014 — The lead runs the Auditor's reviews
- **Status:** ACCEPTED
- **Date:** 2026-11-18 · **Decided by:** Lucas (instruction in chat)
- **Context:** F-011 and F-012 were built under D-011 and D-013 with the plan review skipped,
  and both sat at `CODE_REVIEW` waiting for Codex, which is not installed on the Windows
  machine the work runs on. Asked what happens to the check Codex normally does, Lucas
  answered: "continue as your doing you check from now on".
- **Chosen:** From now on the lead (Claude Code) does the Auditor's checks, starting with the
  code reviews of F-011 and F-012. How the lead does it (the lead's reading of the
  instruction, open to correction):
  - A review is done by **fresh reviewer sub-agents** that wrote neither the spec nor the
    code. They get `AGENTS.md`, the feature file and the diff, never the lead's conclusions,
    and they are read-only (D-010).
  - The lead checks every finding against the code before recording it, writes the round in
    §7 or §9 in the format `AGENTS.md` sets (machine line, reviewed commit, AC evidence,
    findings with severity), and signs it "Auditor (lead, D-014)".
  - Findings are fixed by implementer sub-agents, gated and committed by the lead, who replies
    under each finding. A second round checks the fixes.
  - For features specified by the lead, a plan review round (§7) runs the same way before any
    code is written.
- **Rejected:**
  - *Wait for Codex* — two features, and every later one, would queue behind a tool that isn't
    on this machine. Tempting because it keeps the reviewer a different model from the builder.
  - *The lead reviews its own work directly* — the lead wrote the specs and directed the build,
    so its read is anchored. Tempting because it is one step shorter.
- **Consequences:** No model other than Claude reviews the work, so Lucas's Gate B playtest is
  the only fully independent check. `AGENTS.md` and `CLAUDE.md` still describe Codex as the
  Auditor; they are unchanged, and Codex can still review any branch on request. Only Lucas
  sets `APPROVED` and `DONE`, as before.
- **Revisit if:** a defect reaches Gate B that a second reviewer should have caught, or Codex
  becomes available where the work runs.


## D-013 — F-012 is built stacked on F-011, by a lead with up to two writing implementers
- **Status:** ACCEPTED
- **Date:** 2026-11-18 · **Decided by:** Lucas (instruction in chat)
- **Context:** Lucas asked for slice 2 ("now i need you to begin slice 2") while F-011 was at
  `CODE_REVIEW`. Slice 2 needs F-011's code. D-011 covered F-011 only, and the Builder rules
  say a feature branch is cut from `main`.
- **Chosen:** Slice 2 is one feature, F-012 "The loop" (progression, one-room town, bare HUD),
  on `feature/F-012-the-loop`, cut from the tip of `feature/F-011-floor-structure`. D-011's
  arrangement applies to it unchanged: the lead writes the spec, Lucas's instruction is Gate A,
  the plan review is skipped, up to two Sonnet implementers write on disjoint file lists, and
  only the lead gates and commits. The Auditor's code review and Lucas's Gate B are unchanged.
- **Rejected:**
  - *Wait for F-011 to be DONE* — the build would sit idle behind two gates. Tempting because
    nothing would ever need a rebase.
  - *Three features (F-012, F-013, HUD) as in `PHASE1.md`* — three specs and three reviews for
    parts that only work together. Tempting because it matches the plan's rows.
- **Consequences:** F-011 must be reviewed and merged before F-012. A change to F-011's code in
  review means rebasing F-012. `PHASE1.md` needs its rows merged and renumbered (Direction).
- **Revisit if:** F-011's review forces a rebase that costs more than the wait would have.


## D-012 — Rooms are data; core routes on a navigation grid built from them
- **Status:** ACCEPTED
- **Date:** 2026-11-18 · **Decided by:** Lucas (proposed by the F-011 lead, chosen in chat)
- **Context:** Enemies walk straight at the player and stick on walls. Real rooms need
  pillars and cover (Hexer floor, CX9). D-008 rejected wall geometry in core because every
  level would describe its walls twice.
- **Chosen:** A room is a `RoomData` resource holding an ASCII tile grid (G9). The glue builds
  the wall bodies from it and core builds a `NavGrid` from the same rows, so walls are written
  once. Brains use the grid only to choose a walking direction, and only when the straight
  line to the target is blocked. One room = one sim.
- **Rejected:**
  - *Open rooms, no path finding* — every layout becomes a rectangle with round-able pillars.
    Tempting because it needs no core change.
  - *Godot `NavigationServer2D`* — decisions from an engine server outside core (G6), not
    snapshot-safe. Tempting because it's built in.
- **Consequences:** Refines D-008: core now knows walls **as walkable tiles, for routing
  only**. Hits, projectile stops and charge stops are still decided as D-008 says. Levels are
  grid-shaped (1 tile resolution). Hand-placed wall bodies in a room scene would be invisible
  to routing, so rooms don't have them.
- **Revisit if:** rooms need diagonal or curved walls, or hits must respect line of sight.

## D-011 — F-011 is built by a lead with up to two writing implementers
- **Status:** ACCEPTED
- **Date:** 2026-11-18 · **Decided by:** Lucas (instruction in chat)
- **Context:** Lucas asked Claude Code to run slice 1 (F-011) as orchestrator and lead
  engineer: "you do not implement. you will spawn sonnet 5.5 high subagents to accomplish
  this slice (2 max). supply tasks, gates, tests and answer any implementer agent questions."
  D-010 allowed read-only sub-agents only, and no spec existed.
- **Chosen:** For F-011, the lead writes the spec (§1–§6), Lucas's instruction is Gate A, and
  the Auditor's plan review is skipped. Up to two Sonnet implementers write code on disjoint
  file lists in the one checkout, on the feature branch. They never commit, branch, push, use
  a worktree or edit `studio/`. The lead runs every gate (tests, lint, purity, diff review),
  commits each task and writes §8. The Auditor's code review and Lucas's Gate B are unchanged.
- **Rejected:**
  - *Worktree-isolated implementers* — still what D-010 rejected: `tools/studio` refuses the
    step and merges need a second review. Tempting because two writers can't collide.
  - *Implementers that commit* — two agents moving one branch. Tempting because it saves
    the lead a step.
- **Consequences:** D-010 stands for every other feature until Lucas extends this. F-011's
  file skips `APPROVED` (F-011 §8 DEV-1). Two Godot processes share one `.godot/` cache while
  both implementers test; the lead's full run before each commit is the one that counts.
- **Revisit if:** the slice lands cleanly (then consider making it the default), or two
  implementers collide on files or on the import cache.

## D-010 — Sub-agents: read-only helpers allowed, parallel builds parked
- **Status:** ACCEPTED
- **Date:** 2026-11-16 · **Decided by:** Lucas (proposed by Lucas, reviewed by Direction)
- **Context:** Lucas proposed parallel agents to speed up phase 1. F-007 was blocked on
  2026-11-12 because a second session created a worktree branch and pushed to `main`
  during the build (F-002 C3, C7, C21).
- **Chosen:** The Builder may use up to 3 read-only sub-agents at once, in any session,
  for reading code, checking a spec against `main`, test planning and a self-review pass.
  Each has one objective and reports to the Builder. Sub-agents never write files, commit
  or create branches or worktrees. Only the Builder writes §8 and commits. The Auditor's
  review (§9) is still required.
- **Rejected:**
  - *Parallel builds of independent features in worktrees* — a moving branch blocks any
    autopilot step; two manual builds skip the tool's containment; the session limit is
    shared; the second merge needs a rebase and a new review. Build time (about 1 hour)
    is not the bottleneck. Tempting because the machine is idle during gates.
  - *Worktree-isolated sub-agents in automated sessions* — the worktree and its branch
    make `tools/studio` reject the step. Tempting because isolation sounds safer.
  - *Agent Teams* — experimental; no need shown yet. Tempting because it is the newest tool.
- **Consequences:** One feature builds at a time. Speed comes from the queue (F-010),
  specs written ahead in department chats, and art done in parallel by Lucas.
- **Revisit if:** With the queue running, a feature regularly waits on build time rather
  than on a gate; or phase 1 is done.

## D-009 — Gate A may be automatic for features Lucas marks
- **Status:** PROPOSED
- **Date:** 2026-11-16 · **Decided by:** _pending Lucas_ (proposed by Direction, from F-010)
- **Context:** F-007 waited 2 days for Gate A after the Auditor had approved its plan.
  About 8 phase 1 features remain and waits between steps are the main schedule risk.
- **Chosen:** A feature marked `auto` in `studio/QUEUE.md` passes Gate A without Lucas when
  the Auditor's latest plan round approves and no blocking question is open. The tool sets
  `APPROVED`, never an agent, and records it (commit subject and §11 note). Unmarked
  features, and Gate B for every feature, stay manual.
- **Rejected:**
  - *Automatic Gate A for everything* — new systems (floors, loot, town) need Lucas to
    read the plan; the Auditor checks consistency, not intent. Tempting because it is
    simpler and stops least.
  - *Always manual* — costs a stop per feature that is often not a real decision.
    Tempting because it is the safest.
- **Consequences:** "Only Lucas sets APPROVED" becomes "only Lucas or the queue rule he
  set". A wrong auto-approved plan is caught at the playtest and costs one build.
- **Revisit if:** An auto-approved feature fails its playtest because of the plan.

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
- **Refined at F-005 Gate A (accepted by Lucas, F-005 §10 Q3):** a projectile born already
  overlapping a wall is a **blocked launch**: the glue reports it and it is removed before any
  contact, so it never hits. The per-step speed bound (`speed / step_rate ≤ radius`) is a
  **sampling limit**, not a swept-hit guarantee: hits stay checked only at contact instants
  (D-007), so a graze that exists only between two contacts is missed.
- **Refined at F-006 Gate A (accepted by Lucas, 2026-11-09, F-006 §10 Q1/Q4):** the same rule
  covers a body's planned attack movement (the brute's charge). Core exposes the planned segment;
  the glue sweeps the body's circle against `world` only and reports the reach; short of the plan
  = wall stop. Enemy bodies never count as walls. A segment that **starts inside a wall** is a stop
  (`reached = start`). A body's stop is **applied after that step's contact**, so the moving
  attack can still hit at the step where it meets the wall.

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
