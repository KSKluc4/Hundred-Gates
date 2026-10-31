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
