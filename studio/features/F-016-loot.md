---
id: F-016
title: Basic loot — swords with one trait, drops, the Equipment list (slice 3, second part)
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-21
updated: 2026-11-21
depends_on: [F-001, F-011, F-012, F-014, F-015, D-005, D-006, D-014, D-016, D-017]
pillars: [2, 3]
department: Items & Economy   # values and rules: studio/design/items.md; combat seams: studio/design/combat.md
---

# F-016 — Basic loot

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
Enemies and bosses sometimes leave a sword on the floor; the player walks over it to take it,
sees every sword owned in an Equipment list, and chooses which one to fight with in town or
in the cleared last room before a boss.

**Why now:** slice 3 (D-016) finishes phase 1, and "basic loot" is its biggest missing piece
of play. Lucas put function before looks (D-016 note, 2026-11-21) and decided the design
(D-017). His answers and go-ahead in chat are Gate A.

**Out of scope (explicitly):**
- Any slot but the weapon; a grid inventory; a compare popup; automatic equip.
- Shop, crafting, upgrades, selling, market, currency. A duplicate is only a count.
- Swords that change windup, active, recovery, reach, arc or knockback.
- Random stat rolls: the 15 swords are fixed items.
- A safe room before the boss (Lucas chose the cleared last room).
- Save/load to disk (phase 2). The state is serializable (G7); nothing writes it.
- Sprites, icons, sounds, a pickup animation. Drops are placeholder shapes.
- The sword's name on the HUD; damage numbers; any change to enemy or boss data.
- `PHASE1.md` (Direction's file).

---

## 2. Context  ·  _Planner_

Read `studio/design/items.md` first: the 15 swords, the split rule, the caps and the drop
rules there are binding. Then D-017.

Existing systems this touches (line numbers are from `main` at `7bfdc4d`):
- **Damage.** `PlayerMotor._fire_attack()` calls `_attack_chain.start(_class_data.attack_chain,
  _facing)` (`src/core/player/player_motor.gd:458-461`). `AttackChain.start` latches a private
  copy, `_attack = chain[index].duplicate()` (`src/core/player/attack_chain.gd:23-25`), and
  `build_hitbox()` reads `_attack.damage` once (`:107`). The latched attack is already in the
  snapshot (`:119`, `:131`). `ClassData` and its `AttackData` are shared, cached resources and
  must never be written.
- **Max HP.** `ClassData.max_hp` is read by `PlayerMotor.setup` and `apply_data`
  (`player_motor.gd:99`, `:113`), by `FloorScene` for `FloorRun` (`src/world/floors/
  floor_scene.gd:60`) and by `TownScene` (`src/world/town/town_scene.gd:140`). A new `Room`,
  `Player` and `PlayerMotor` are built for every room; HP is carried as `FloorRun._entry_hp`
  and applied with `set_hp()`, which clamps to max (`src/world/floors/room.gd:350`).
  `CombatState.set_max_hp` never heals and clamps HP down.
- **Dash cooldown.** One reader: `_end_dash()` (`player_motor.gd:498`).
- **Room-clear heal.** `FloorRun.report_room_cleared(current_hp)` computes
  `roundi(_max_hp * _rules.room_clear_heal_fraction)` (`src/core/floors/floor_run.gd:62-75`);
  `advance()` gives the boss room's full heal (`:93-94`).
- **Session.** `TowerSession` (`src/core/floors/tower_session.gd`) owns `TowerProgress`; one
  `Game` is one character; `Shell` frees the `Game` on quit to title. `_clear_visit()` leaves
  progress alone. The session never learns that a room was cleared: `FloorRun` knows
  (`get_room_index()`, `is_room_cleared()`), and lives for one floor visit.
- **Walk-over checks are core checks** on `motor.get_position_tiles()`, called from the scene's
  `_physics_process` (`FloorRun.is_exit_reached`, `TownGate.check`). There is no `Area2D` in
  `src`. `FloorScene` reads death first and returns (`floor_scene.gd:67-78`).
- **Deaths.** `CombatState.died` is emitted inside the contact step, in candidate order
  (`src/core/combat/combat_state.gd:44-52`). The kill count is recounted, not an event.
- **Steps.** `CombatSim.tick()` runs `CombatTiming.step_count(delta, rate)` combat steps per
  physics tick (4 at 30 ticks/s, 1 at 120), each ending with `_apply_contact()` and every
  combatant's `end_step()` (`src/core/combat/combat_sim.gd:74-91`). The wave director is
  attached with `set_waves()` and stepped there. Anything decided once per physics tick
  depends on the tick rate; anything decided per combat step does not. Placed enemies and
  reinforcements are all built with the room (`src/world/floors/room.gd:285-292`).
- **Randomness.** There is none in `src/core`. Enemy AI and the wave director are fully
  deterministic.
- **Menus (F-015).** `ShellFlow` (13 methods, 7 states), `ShellMenus` (texts, ids, focus),
  `MenuPanel` (`open`, `set_body`, `set_entry_text`, `set_entry_enabled`; no scrolling; the
  0.3 s choose guard restarts on every `open()`), `Shell._on_entry_chosen`. A list of about 14
  buttons is the most a 640 × 360 screen holds. `GateMenu` is a bare list with no text area;
  `TownScene` opens it.
- **HUD.** One banner label; a new banner replaces the one showing (`src/ui/hud/hud.gd:128`).
- **Texts.** Every player-facing string of a module lives in one place (F-012/C16, F-015/C10).
- **Data checks.** Resources have `validate(...) -> PackedStringArray`; `Tunables` only
  preloads (path constants tagged `# G5`); consumers validate and build nothing on errors.
  `tools/check_core_purity` forbids textures and scenes in `src/core`.

Relevant decisions: D-005 (class data), D-006 (death keeps everything), D-007 (combat step),
D-012 (rooms are data), D-014 (reviews), D-016 (slice 3), **D-017 (this design)**.
Relevant features: F-001 (motor), F-011/F-012/F-014 (floors, loop, waves), F-015 (menus).

**Two rules of F-015 this feature changes, on purpose:**
- F-015/C6 and AC15 say a pause changes nothing in the game. From now on: a pause changes
  nothing **unless a sword is equipped in it**, which is only possible where no enemy is
  alive (C14).
- F-015 §3 said it would revisit the one-column menu "if a menu needs … an inventory". The
  Equipment list stays one column and is shown in pages (C17); a grid is phase 2 (D-017).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: the sword is a loadout over the class, owned by the session
- **How it works:** `SwordData` resources and per-floor `FloorLoot` tables are data. The
  session owns a `CharacterLoot` (inventory, seeded roller, which boss swords were taken). A
  `PlayerLoadout` turns class + equipped sword into four values (hit damages, max HP, dash
  cooldown, heal bonus) that the motor and `FloorRun` read instead of the class's. Each room
  has a `RoomLoot` that hears its enemies die, rolls at one fixed point of the tick, and holds
  the drops until the player's position takes them. The Equipment list is one more `MenuPanel`
  menu.
- **Why chosen:** every seam already exists (the latched attack copy, the per-room motor, the
  core position checks, the session's lifetime). Nothing shared is written; a null sword is
  exactly today's game, so existing tests need no loot.
- **Costs we're accepting:** the motor gets a second source of values beside `ClassData`;
  `ShellFlow` gets an eighth state; `ListMenu` gets a third addition (a focus hook); the gate
  menu grows a text area.
- **Would revisit if:** a second slot or a second class arrives (phase 2): then the loadout
  becomes a list of modifiers.

### ❌ Rejected: write the sword's values into `ClassData` / `AttackData`
- **How it would work:** duplicate or mutate the class resource when a sword is equipped.
- **Why rejected:** they are shared cached resources (`game.gd:58`); a write leaks into every
  test and every later character. A duplicate per equip breaks `assert_same` style checks and
  F5 reload (`player.gd:86-115`).
- **Tempting because:** the motor would need no change.

### ❌ Rejected: roll the drop inside the `died` signal, or in the world's `Enemy` node
- **Why rejected:** the signal fires in the middle of the contact step; the node is
  presentation (G6). Rolls must happen in core at one fixed point (C9), or two machines
  disagree later.
- **Tempting because:** `Enemy` already listens to `died` and knows where it is.

### ❌ Rejected: rolling and taking once per physics tick, from the scene
- **How it would work:** `FloorScene._physics_process` calls the loot after the combat tick,
  beside the exit check, and skips it on the tick the player dies (the first draft of C9).
- **Why rejected:** an enemy killed up to three steps before the player dies shares the
  death tick at 30 ticks/s and not at 120, so the roller would draw at one rate and not at
  the other, and every later drop would differ (plan review PR-2). A dash covers 0.67 tiles
  per tick at 30, so a pass near a drop could take at one rate and miss at another.
- **Tempting because:** the exit and the gate are checked that way.

### ❌ Rejected: `Area2D` pickups
- **Why rejected:** no physics detection exists in the project; walk-over checks are core
  position checks (G6), and F-015 stops the physics space in a pause.
- **Tempting because:** it is the engine's usual way.

### ❌ Rejected: one float chance per kill written in data
- **Why rejected:** Lucas tunes per floor run. A floor names its drops per run; the chance is
  derived from the floor's kills, so changing a room's kill target does not change the yield.
- **Tempting because:** it is one number and no division.

### ❌ Rejected: scrolling in `MenuPanel`
- **Why rejected:** the panel's click rules were the hardest part of F-015 (four review
  rounds); wheel ticks already restart its guard. Pages reuse `open()` as it is.
- **Tempting because:** 15 swords do not fit on one screen.

### ❌ Rejected: the guarantee tied to "floor not yet cleared"
- **How it would work:** the boss always drops on the win that clears the floor. This is the
  literal reading of Lucas's "the first kill of each boss always drops something".
- **Why rejected:** a drop can be lost after that win (death by a projectile still flying),
  and the guarantee would be gone with nothing taken. It is tied to **taking** a boss sword
  of that floor instead (C11): the same in every case but that one, where it is kinder. Put
  to Lucas as §10 Q1; one line to reverse.
- **Tempting because:** `TowerProgress.mark_floor_cleared()` already returns "first time".

### ❌ Rejected: everything in D-017's rejected list
More slots, grid, auto equip, compare popup, switching anywhere, a safe room, loss on death,
Knockback, Opener, speed or reach swords, shop/crafting, random rolls. Not even partially.

---

## 4. Constraints  ·  _Planner_
Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | **`SwordData`** (`src/core/items/sword_data.gd`, Resource): `id: StringName`, `display_name: String`, `damage: int`, `weights: PackedInt32Array` (empty = the class chain's own damages), `kind: Kind` (`NONE, HEAVY_FINISHER, QUICK_CUTS, VITALITY, QUICKSTEP, MENDING`), `max_hp_bonus: int`, `dash_cooldown_cut: float`, `room_heal_bonus: float`. `get_hit_damages(class_data) -> PackedInt32Array`. `validate(class_data, rules) -> PackedStringArray`. The 15 swords of `items.md` are `data/items/swords/<id>.tres`, with exactly its numbers. | G9, D-017 |
| C2 | **Split rule.** `SwordMath.split(total, weights) -> PackedInt32Array` (static, `src/core/items/sword_math.gd`), in integers: hit `i` gets `(total × w_i) / W` (integer division, `W` the sum of the weights); the points left over go one each to the hits with the largest remainder `(total × w_i) mod W`; among equal remainders the last hit comes first, then hit 0, 1, 2 … in order. One entry per weight; the entries add up to `total`. It returns an empty array for an empty list, a weight `< 1` or a `total < 0`, and never divides by zero. | Lucas: the rule belongs in the spec; integer HP |
| C3 | **Validation of a sword** refuses: an empty id or name; `damage < 1`; weights of another size than the class chain; a weight `< 1`; any hit `< 1`; a chain above `max_chain_damage` (49); all hits but the last together above `max_light_hits_damage` (29); the last hit above `max_finisher_damage` (29); a negative bonus; `NONE` with weights or any bonus; a utility kind with weights, without its own bonus, or with another kind's bonus; `VITALITY` above `max_hp_bonus_cap` (8); `QUICKSTEP` whose cooldown would fall below `min_dash_cooldown`; `HEAVY_FINISHER` without weights or whose last hit is not above the standard split's; `QUICK_CUTS` without weights or whose last hit is not below the standard split's. "Exactly one trait" is thereby a data rule. | Combat's breakpoints; D-017 |
| C4 | **Tunables** `ItemTunables` (`src/core/tunables/item_tunables.gd`, `data/tunables/items.tres`, `Tunables.ITEM_TUNABLES_PATH`, `Tunables.items`): `max_chain_damage = 49`, `max_light_hits_damage = 29`, `max_finisher_damage = 29`, `max_hp_bonus_cap = 8`, `min_dash_cooldown = 0.2`, `pickup_radius_tiles = 0.8`, `equipment_page_size = 8`. With `validate()`. No such number in code. | G2 |
| C5 | **`FloorLoot`** (Resource): `regular_drops_per_run: float`, `regular_swords: Array[SwordData]`, `boss_swords: Array[SwordData]`, `boss_percents: PackedInt32Array`. **`LootCatalog`** (Resource): `starter_sword`, `floors: Array[FloorLoot]` (index = floor − 1); `get_sword(id)`, `get_all_swords()`, `get_floor_loot(floor_number)` (null when there is none); `validate(tower, class_data, rules)` refuses: no starter; a floor count other than the tower's; a duplicate id; an invalid sword; percents and swords of different sizes; a percent `< 1`; percents adding up above 100; a negative drops-per-run; drops per run on a floor with no kill before the boss; a chance per kill above 1. An empty boss table or an empty pool is allowed. Shipped: `data/items/loot_catalog.tres` and `data/items/floor_<n>_loot.tres` with `items.md`'s tables; `Tunables.LOOT_CATALOG_PATH`, `Tunables.loot_catalog`. | G9, G5 |
| C6 | **Chance per kill** of a floor = `regular_drops_per_run / FloorData.get_regular_kill_count()` (new method: the kill targets of every room that is not the boss room, added up). It is never a number in data. | Lucas: tuned per floor run |
| C7 | **`PlayerLoadout`** (RefCounted): `PlayerLoadout.of(class_data, sword, rules)`; `sword` may be null. `get_hit_damage(index)` (the sword's split, or the class attack's own damage), `get_max_hp()` (class + bonus), `get_dash_cooldown()` (`maxf(rules.min_dash_cooldown, class − cut)`, or the class value with no cut), `get_room_heal_bonus()`, `get_sword()`. With a null sword every value is the class's: **a game without a sword behaves exactly as `main`**. | No regression; one place for the arithmetic |
| C8 | **The motor reads the loadout.** `PlayerMotor.set_sword(sword, rules)` (null = class values). The motor builds its `PlayerLoadout` from the class data **it holds**, and builds it again in `setup()` and `apply_data()` (F5): both keep the sword, and a fresh `ClassData` is read at once. Called before `setup()` it only stores the sword; `setup()` then starts at the loadout's max HP. Max HP goes through `CombatState.set_max_hp` (no heal, clamps down); the cooldown is read in `_end_dash()`; `_fire_attack()` passes the hit's damage to `AttackChain.start(chain, direction, damage := -1)`, which writes it into its latched copy only (negative = the attack's own). Windup, active, recovery, arc, range and knockback are never touched. No new snapshot key in `PlayerMotor`, `AttackChain` or `CombatState`: the sword is setup data, like `ClassData`. On a restore the sword is set before `from_dict()`. | Pillar 2; G7 pattern; plan review PR-8 |
| C9 | **`RoomLoot`** (RefCounted, one per room), attached with `CombatSim.set_loot(loot)` (null detaches; with none nothing in the sim changes). `watch_enemy(combatant)` for every enemy that counts toward the kill target, `watch_player(combatant)` for the player. Deaths are queued in the order `died` fires. **At the end of every combat step**, after `_apply_contact()` and every `end_step()`, the sim calls the loot once: (1) it rolls for every death queued since its last call, in order (also one fired between ticks), and lays each drop at that enemy's position; a watched combatant is rolled once, ever, however often it dies; (2) if the player is alive, every drop within `pickup_radius_tiles` of the player (centre to centre, `<=` radius plus `Geometry.DISTANCE_EPSILON`) is taken, in the order they dropped. Enemy deaths are rolled whether or not the player is alive; a dead player takes nothing. Taking adds to the inventory and to a list the scene empties with `pop_taken() -> Array[StringName]`. `take_all()` takes the rest, and nothing when the player is dead. `get_drops()` for drawing. `to_dict()`/`from_dict()` hold the lying drops: sword id, position, and the floor number when the boss dropped it (0 otherwise); the queue is always empty between steps. The sim's own snapshot is unchanged (its keys are pinned by tests); like `FloorRun.to_dict()`, nothing calls `RoomLoot.to_dict()` until save/load. | G6, G1; plan review PR-2, PR-5 |
| C10 | **Regular kill:** exactly one `randf()`; a drop when it is below the chance per kill; only then exactly one `randi_range(0, n − 1)` for the sword, each of the pool's `n` equally likely. The boss room's enemy never rolls as a regular kill. A floor without `FloorLoot`, an empty pool or zero drops per run rolls nothing and **draws nothing**; so does a boss with an empty table. | D-017 |
| C11 | **Boss kill:** if the character has not yet **taken** a boss sword of this floor: one `randi_range(1, sum)` over the percents, and a sword always drops. Otherwise one `randi_range(1, 100)`. In both, sword 0 is the rolls `1 … p0`, sword 1 the next `p1`, and so on; a roll above the sum is nothing. That mapping is one pure static function, `LootRoller.boss_pick(roll, percents) -> int` (−1 = nothing). The flag is set when a sword that this floor's boss dropped is taken, not when it drops. **This is the override of `items.md`'s first wording ("the win that clears the floor"); `items.md` now says the same as this row.** | Lucas: "first win always drops, repeats 60%"; §3; Q1 |
| C12 | **`LootRoller`**: one `RandomNumberGenerator` per character, always seeded explicitly (never self-seeded in core; a session on which `set_loot` was never called uses seed 0). `to_dict()` holds its seed and state; `from_dict()` restores them so the following draws are identical. Nothing else in `src/core` draws. | G7; co-op later |
| C13 | **`Inventory`** (RefCounted): `add(id)`, `get_count(id)`, `has(id)`, `get_ids()` (order of first acquisition), `equip(id) -> bool` (only an owned sword; equipping the equipped one is a yes that changes nothing), `get_equipped_id()` (`&""` when nothing is), signal `changed`, `to_dict()`/`from_dict() -> bool` (refuses a count `< 1`, an equipped id that is not owned, wrong types; the empty inventory with nothing equipped is valid). **`CharacterLoot`** (RefCounted) owns the inventory, the roller, the catalog and the floors whose boss sword was taken; `setup(catalog, seed)` gives and equips the starter (a null catalog gives nothing and makes every roll a no); `get_inventory()`, `get_equipped_sword()`, `is_boss_sword_taken(floor_number)`, `make_room_loot(floor_number, floor_data, room_index, rules)`, `to_dict()`/`from_dict() -> bool`. `from_dict` also refuses an owned id the catalog does not have, a taken floor outside the catalog's floors, with a catalog, a state with nothing equipped; and, with no catalog, any inventory but the empty one (the roller's seed and state are free in both). A refusal changes nothing. | G7; plan review PR-5 |
| C14 | **`TowerSession`** owns one `CharacterLoot`, created in `setup()` with no catalog and seed 0, left alone by `_clear_visit()`, in `to_dict()`/`from_dict()`. `set_loot(catalog, seed)`, `get_loot()`. **`can_equip(pre_boss_room_cleared: bool) -> bool`**: true in `TOWN`; in `FLOOR` the fact passed in; false in `DEATH_PAUSE`. **`equip_sword(id, pre_boss_room_cleared) -> bool`** refuses when `can_equip` is false or the sword is not owned. `FloorRun.is_pre_boss_room_cleared()` is true when the current room is the one before the boss room and is cleared. `Game` only passes the fact on (F-015/C5: it decides nothing). | Lucas: town and cleared last room only |
| C15 | **World.** `Game.loot_catalog` (default `Tunables.loot_catalog`; read once in `_ready`; null = no loot) and `Game.loot_seed` (0 = a non-zero one is drawn at `_ready`, in the world, not in core). The class data is loaded before the catalog is validated; a catalog with validation errors is a setup error like the others (`get_setup_errors()`), and nothing is built. `Game.can_equip_sword()`, `Game.equip_sword(id) -> bool`: on a yes the sword of the player now on screen and the values of the running `FloorRun` change at once. Every room's player gets the current sword **before** its entry HP is applied. `FloorRun.set_loadout_values(max_hp, room_heal_bonus)` clamps its entry HP down to the new max and never raises it; `FloorRun.setup()` is given the loadout's max HP, so a floor entry starts there; the heal is `roundi(max_hp × minf(1.0, fraction + bonus))`; the boss room's full heal uses the loadout's max HP. The town player has the loadout's max HP. | C7 applied; plan review PR-4 |
| C16 | **Leaving a room.** Whatever advances to the next room (walking through the exit, the boss room's door, debug N) and Return to town take what lies in the room (`take_all()`) before the room is freed, and whoever calls `take_all()` also empties `pop_taken()` and reports it for the banner (C20). Death takes nothing: untaken swords are gone with the room, also when debug N is pressed after a death. Debug R (restart room) discards them. **This is the override of `items.md`'s and `floors.md`'s first wording ("lost on Return to town"); both now say the same as this row.** | A boss's sword is not lost by oversight, and the guaranteed roll cannot be fished; Q2 |
| C17 | **Equipment menu.** `ShellFlow.State.EQUIPMENT` (added last in the enum), `open_equipment()` (from `PAUSED`), `close_equipment()`, `back()` returns to `PAUSED`, `is_game_paused()` is true. The pause menu gets `Equipment` as its second entry, on a floor and in town. Entries, in order: the owned swords of the page (order of first acquisition), `Next page` and `Previous page` when there is one, `Back` (routed by state: here it closes the Equipment menu). A page holds `equipment_page_size` swords. Opening shows the page of the equipped sword with the focus on it; after a page change the focus is on the page's first sword. The page shown is the one menu variable `Shell` keeps (say so in its header). A sword's entry: `<name> — <damage> (<h1>/<h2>/<h3>) — <trait>`, then ` ×<n>` when `n > 1`, then ` [equipped]`. Where equipping is not allowed every sword entry is disabled and the body says where it is. Choosing a sword calls `Game.equip_sword`; on a yes the two entries change **in place** (`set_entry_text`): no `open()`, the focus stays, the guard does not restart. Changing page is an `open()`. | Lucas: a list, no grid; F-015 DEV-11 |
| C18 | **Texts** in one file, `src/ui/items/item_texts.gd` (static): heading `Equipment`; bodies `Choose a sword to equip it.`, `Swords can be changed in town, or in the last room before a boss once it is cleared.`, `No swords.`; traits `No trait`, `Heavy finisher`, `Quick cuts`, `Max HP +%d`, `Dash cooldown -%.2f s`, `Room heal %d%% of max HP` (the base fraction plus the bonus, at most 1, `roundi` of the percentage, so 30 % + 0.05 reads 35); `Next page`, `Previous page`; `Found: %s` (names joined by `, `; with more than two, the first two and ` +%d more`); gate lines (C19). The pause entry's text and id live in `ShellMenus` with the others. No item string anywhere else. | F-012/C16; plan review PR-9 |
| C19 | **Odds at the gate.** `gate_menu.tscn` gets a node `Odds` beside `Panel` (`Panel/List` stays as it is): its own panel with one label, anchored to the bottom centre of the screen, hidden when it has nothing to say, so the list never moves. For the floor whose entry has the focus it shows `Boss drops:`, one line per sword `<percent>% chance: <sword entry text without count and mark>`, and then either `Your next win is sure to drop one of these, in these proportions.` (no boss sword of that floor taken yet) or `Nothing: <100 − sum>%` (no such line when the sum is 100). Nothing for `Stay in town` or a floor without a table. `ListMenu` gets one hook, `_focus_moved(index)`, empty in the base, called where the focus changes; `GateMenu.open(entries, odds_by_floor := {})` (`{floor_number: String}`). The texts are built by `ItemTexts`; `Game` hands them to `TownScene`, which passes them on every `open()`, also the one after debug N. | Lucas: "the player can see those odds"; plan review PR-6, PR-9 |
| C20 | **Pickup notice and drops on screen.** Each physics tick the scene empties `pop_taken()`; what was taken is shown on the HUD banner as `Found: …` for `Tunables.tower.banner_duration`. If `Game` shows another banner in the same physics frame (the heal, the floor cleared), the two are joined, the other first whichever came first: `+30 HP · Found: Twin Edge`. Banners are still shown in the callback that reports them, as today (tests read them at once): `Game` keeps the parts and `Engine.get_physics_frames()` of its last banner and rebuilds the text when another part arrives in the same frame. Otherwise a new banner replaces the one showing, as before. A drop is drawn by a `Room` child from `RoomLoot.get_drops()` (the `WaveMarkers` pattern), a placeholder shape whose size and colour are exports of that node; it reads no core state but the drops. | G6; Art owns the look (IX3); plan review PR-7 |
| C21 | **Core purity and data.** Everything in `src/core/items/` is RefCounted or Resource, no Node, no texture, no scene. No third-party code. Item paths are constants tagged `# G5`. | G4, G5, G6 |
| C22 | **Existing tests.** The shared helpers set `Tunables.loot_catalog = null` before each test and restore it after (the existing pattern for `Tunables`), so every existing test runs without loot, also in games a `Shell` builds on Start. These files may be edited, each edit listed in §8 with its reason: `tests/core/shell/test_shell_flow.gd` (states, methods, situations), `tests/ui/test_f015_menu_texts.gd` and `tests/scenes/test_f015_shell.gd` (the pause menu's entries), `tests/core/floors/test_f015_session.gd` and `tests/core/floors/test_tower_session.gd` (snapshot keys), `tests/scenes/f012_game_test.gd`, `tests/scenes/f015_shell_test.gd` (helpers). No test is deleted without a replacement. **All other tests stay green unedited** (`tests/ui/test_gate_menu.gd` and the tests that pin `CombatSim`'s snapshot keys among them); if one cannot, stop and log it before touching it. | F-015/C18; an unlisted edit is a 🔴 |
| C23 | **Determinism.** Two sessions with the same seed, catalog and sequence of calls give the same drops and the same snapshots, step for step, at 30, 60 and 120 physics ticks per second. A snapshot taken at any tick and restored into a fresh session continues identically. **One exception, inherited:** the exit check and "death first" are decided once per physics tick (F-011, F-012), so a run in which the player reaches the exit, or takes a boss's sword, and dies within one 30-ticks/s tick may differ between rates; this feature does not change that. | G1, G7; plan review PR-23 |

**Must not break:** every F-001 to F-015 behaviour; the whole suite (2,579 tests on `main`);
with no catalog the game is `main`; boss fights at the starter sword are unchanged to the
tick; F-015's pause rules (C2 guard, C6 for a pause without an equip, the choose guard);
`gdlint`, `gdformat --check`, `tools/check_core_purity`, a clean headless boot.

---

## 5. Acceptance Criteria  ·  _Planner_
Testable, observable. The Auditor checks each one.

- [ ] AC1: `SwordMath.split(d, [10, 10, 22])` gives 9/8/19, 9/9/19, 9/9/20, 9/9/21, 10/9/21,
  10/10/21, 10/10/22, 10/10/23, 11/10/23, 11/11/23, 11/11/24, 11/11/25, 12/11/25, 12/11/26
  for `d` = 36 … 49, and for these weights every hit is non-decreasing in `d` (not a property
  of the rule in general: `[3, 5, 7]` gives 2/2/3 at 7 and 1/3/4 at 8, also a test). For 1 to
  4 random weights and totals 0 … 200 the hits add up to the total and differ from the exact
  share by less than 1. The refusals of C2 return an empty array.
- [ ] AC2: each of the 15 shipped swords loads, validates, and has exactly the damage, hits
  and trait value of `items.md`; the shipped catalog validates against the shipped tower and
  class; its three boss tables and its regular pool are `items.md`'s.
- [ ] AC3: each refusal of C3 and of C5 has a test that fails without it.
- [ ] AC4 (a data test, not a test of the motor): against the shipped enemy data every
  shipped sword kills a chaser in 4 hits, a caster in 3 and a brute in 9, starting the chain
  fresh.
- [ ] AC5: with a null sword `PlayerLoadout` returns the class's values, and a fight run with
  `set_sword(null, …)`, with no call at all, and with the starter sword gives identical
  snapshots at every tick.
- [ ] AC6: with a sword equipped, the three hits take its three damages off an enemy's HP
  (a sword whose hits differ from the class's, so a motor that ignores the sword fails);
  windup, active, recovery, arc, range and knockback of each hit are those of the class
  attack; the shared `AttackData` and `ClassData` are unchanged after the fight.
- [ ] AC7: Vitality: max HP is class + 8; setting the sword does not heal; switching to a
  sword without it clamps HP to the class max. Quickstep: the cooldown after a dash is the
  class value minus the cut, never below `min_dash_cooldown`. Mending: the room-clear heal is
  `roundi(max_hp × minf(1.0, fraction + bonus))`, follows a changed
  `room_clear_heal_fraction`, and is never above max HP with a fraction of 1. The sword
  survives `setup()` and `apply_data()`; after `apply_data()` with another class resource the
  values follow that resource.
- [ ] AC8: the chance per kill of the shipped floors is 1/27, 1/51 and 1/38 (from
  `get_regular_kill_count()` = 27, 51, 38); changing a room's kill target changes the chance
  and not the drops per run.
- [ ] AC9 (exact): `LootRoller.boss_pick` over the rolls 1 … 100 with percents 30, 20, 10
  gives exactly 30, 20, 10 and 40 times nothing; over 1 … 60 exactly 30, 20, 10. The pool pick
  maps each index 0 … n − 1 to its own sword. After each kind of roll the roller's generator
  is in the state of a reference generator with the same seed on which the test made the
  same calls with the same arguments (`randf()`; `randi_range(0, n − 1)`; `randi_range(1,
  sum)`; `randi_range(1, 100)`), and none for a floor without loot, an empty pool, zero
  drops per run or an empty table. Over 1,000 kills of each kind the outcomes equal those
  the test computes from the values the reference returned.
- [ ] AC10 (statistical, fixed seed): 20,000 regular kills at chance `p` drop within 4
  standard deviations of `20,000 × p`, each pool sword within 4 of an equal share; 6,000
  repeat boss wins and 6,000 guaranteed wins give each sword within 4 standard deviations of
  its share; guaranteed wins never give nothing.
- [ ] AC11: the boss guarantee holds until a boss sword of that floor is **taken**: a drop
  left behind by a death keeps the next win guaranteed; after one is taken the next win rolls
  the percentages. Other floors' flags are untouched.
- [ ] AC12: same seed and calls → same drops and equal snapshots; another seed → different
  drops; a session saved with `to_dict()` at any point of a scripted run and restored into a
  fresh one gives the same later drops (C12, C23). `from_dict` refuses each malformed shape
  of C13 and leaves the state as it was; the empty state of a session without a catalog
  round-trips. `RoomLoot.to_dict()`/`from_dict()` round-trip the lying drops with their
  source, and a boss sword taken after a restore sets that floor's flag.
- [ ] AC13: a killed enemy's drop appears at its position at the end of the combat step of
  its death; a player 0.01 tiles inside the radius takes it in that step and 0.01 outside
  does not; the inventory count rises; the banner says `Found: <name>`. Two drops in reach
  are taken in drop order and named in one banner. A banner shown by `Game` in the same tick
  is joined in front (C20).
- [ ] AC14: an enemy that dies in an earlier combat step of the same 30-ticks/s tick in which
  the player dies is rolled, at 30, 60 and 120 ticks per second alike, and so is one that
  dies in the same step; a dead player takes nothing, by walking or by `take_all()`; the
  drops lying in the room are not in the inventory after the death is confirmed. A death
  fired between ticks is rolled at the next step; an enemy that dies twice is rolled once.
- [ ] AC15: walking through an exit, the boss door, debug N and Return to town each take
  what lies in the room and show `Found:`; at an exit below full HP it is joined behind the
  heal; with three swords it reads the first two and ` +1 more`; debug R takes nothing.
- [ ] AC16: a new game owns the Recruit's Sword ×1, equipped; death, Return to town and
  clearing a floor keep the inventory and the equipped sword; quit to title and Start again
  give a fresh one. A second pickup of an owned sword shows `×2`.
- [ ] AC17: `can_equip`/`equip_sword` say yes in town; on a floor only in the cleared room
  before the boss (not in that room before it is cleared, not in an earlier cleared room, not
  in the boss room cleared or not, not during the death pause); never for a sword not owned.
  A floor entered at the boss has no place to equip.
- [ ] AC18: equipping in town changes the town player's max HP and, on the next floor, the
  hits, cooldown and heal; equipping in the cleared pre-boss room changes the player on
  screen at once and the boss room is entered at the new max HP. A floor entered with
  Vitality starts at 108/108. In a room entered at 105, taking Vitality off leaves at most
  100 and a `FloorRun` whose own snapshot it accepts back. `loot_seed = 0` gives the
  session a non-zero seed; a given seed is used as it is.
- [ ] AC19: `ShellFlow`: `EQUIPMENT` is reached only from `PAUSED`, `back()` and
  `close_equipment()` return to `PAUSED` with the focus on `Equipment`; the game stays
  stopped; Escape, pad B and pad Start behave as in `SETTINGS`. Every other transition of
  F-015 is unchanged.
- [ ] AC20: the Equipment menu shows the entries of C17 with the exact texts of C18; with 9
  owned swords and a page size of 8 there are two pages; with a fixture of 17 the middle page
  has both `Next page` and `Previous page`, and its whole panel (8 swords, both page entries,
  `Back`, heading, the two-line body) is inside the 640 × 360 screen; page entries appear
  only where there is a page; the menu opens on the equipped sword's page with the focus on
  it; after `Next page` or `Previous page` the focus is on that page's first sword.
- [ ] AC21: where equipping is allowed, choosing a sword equips it, the `[equipped]` mark
  moves, the focus stays, the panel was not reopened (the choose guard did not restart); the
  equipped sword chosen again changes nothing. Where it is not allowed the sword entries are
  disabled, nothing can be chosen by key, pad, click or `choose()`, and the body says where.
- [ ] AC22: a pause with no equip leaves the game's snapshots equal before and after (F-015
  AC15 still passes unedited); after a pause with an equip, the two-tick input guard and the
  physics space behave as in F-015.
- [ ] AC23: at the gate, focusing a floor shows its boss's three swords with their percents
  and, while none was taken, the guarantee line; after one is taken the last line is
  `Nothing: 40%`, and a table adding up to 100 has no such line; the odds are still there
  when the gate reopens after debug N; `Stay in town` hides the area; with no catalog it is never shown; the list
  panel's position is the same whichever entry has the focus; with 7 entries and 5 lines both
  panels are inside the screen and do not overlap; `tests/ui/test_gate_menu.gd` passes
  unedited.
- [ ] AC24: drops are drawn where they lie and disappear when taken; the marker node reads
  only `RoomLoot.get_drops()`.
- [ ] AC25: with `Tunables.loot_catalog = null` the full suite of `main` passes with only the
  edits C22 lists; a catalog with an error makes `Game` report it in `get_setup_errors()` and
  the title shows the start failure, as for the other data.
- [ ] AC26: 30, 60 and 120 ticks per second give the same drops, pickups, inventory and
  roller state for a scripted run through a fixture floor (same seed), compared in game time.
  The script contains an enemy killed in an earlier step of the 30-ticks/s tick in which the
  player dies, and a dash placed so that the drop is in reach only in steps that are not the
  last step of a 30-ticks/s tick (asserted from the positions, so a build that takes once
  per tick fails).
- [ ] AC27: no file under `src/core` but `loot_roller.gd` names `randi`, `randf`, `randomize`
  or `RandomNumberGenerator` (a test reads the sources).
- [ ] AC28: `gdlint src tests`, `gdformat --check src tests`, `tools/check_core_purity` and
  the headless boot are clean; nothing is left in `user://` by the suite.

**How to verify manually (Lucas, Gate B):** start a game; pause in town: `Equipment` lists
the Recruit's Sword, equipped. Walk to the gate: floor 1 shows the Warden's three swords and
the guarantee line. Clear floor 1: a sword now and then lies where an enemy died; walk over
it and read the banner. In the last room before the Warden, clear it, pause, open
`Equipment`, switch swords; try the same one room earlier (the list is grey). Beat the
Warden: he always leaves a sword the first time. Die on floor 2: the swords are still there.

---

## 6. Task Breakdown  ·  _Planner_
Small, ordered, each independently committable.

One commit per task. Order: T1, then T2 ∥ T3, then T4 ∥ T5, then T6, then T7. The two
parallel pairs have disjoint file lists and neither calls the other's new code.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Data, arithmetic and texts: `SwordData`, `SwordMath`, `ItemTunables`, `FloorLoot`, `LootCatalog`, `PlayerLoadout`, `ItemTexts`, `FloorData.get_regular_kill_count()`; the 15 swords, three floor tables, the catalog, the tunables file; `Tunables` paths and preloads; the fixture catalog every later task's tests use | `src/core/items/{sword_data,sword_math,floor_loot,loot_catalog,player_loadout}.gd`, `src/core/tunables/item_tunables.gd`, `src/core/floors/floor_data.gd`, `src/ui/items/item_texts.gd`, `src/autoload/tunables.gd`, `data/items/**`, `data/tunables/items.tres`, `tests/core/items/{item_fixtures,test_sword_math,test_sword_data,test_loot_catalog,test_player_loadout,test_shipped_items}.gd`, `tests/core/test_item_tunables.gd`, `tests/ui/test_f016_item_texts.gd` | AC1–AC4, AC5 (loadout part), AC8, texts of C18/C19. `.gitkeep` in `data/items` goes. `ItemTexts` signatures: `sword_text(sword, hits, count, equipped, base_heal_fraction) -> String`, `trait_text(sword, base_heal_fraction) -> String`, `found_text(names: PackedStringArray) -> String`, `odds_text(floor_loot, class_data, base_heal_fraction, guaranteed: bool) -> String` (empty for a null or empty table) |
| T2 | Loot state: `Inventory`, `LootRoller`, `CharacterLoot`, `RoomLoot`; `CombatSim.set_loot` and its call per step; `TowerSession` and `FloorRun` additions | `src/core/items/{inventory,loot_roller,character_loot,room_loot}.gd`, `src/core/combat/combat_sim.gd`, `src/core/floors/{tower_session,floor_run}.gd`, `tests/core/items/test_{inventory,loot_roller,character_loot,room_loot}.gd`, `tests/core/combat/test_f016_sim_loot.gd`, `tests/core/floors/test_f016_{session,floor_run}.gd`, the two session tests of C22 | AC7 (heal), AC9–AC12, AC14, AC17, AC27, core parts of AC13 and AC15 |
| T3 | The motor reads the loadout: `set_sword`, the damage argument of `AttackChain.start`, cooldown, max HP, `setup`/`apply_data` | `src/core/player/{player_motor,attack_chain}.gd`, `tests/core/player/test_f016_loadout.gd` | AC5–AC7 |
| T4 | Menus without the world: `ShellFlow.EQUIPMENT`, the pause entry, the Equipment entries builder with pages, the `ListMenu` hook and the gate's `Odds` node | `src/core/shell/shell_flow.gd`, `src/ui/menus/{shell_menus,list_menu}.gd`, `src/ui/items/equipment_menu.gd`, `src/ui/town/gate_menu.{gd,tscn}`, `tests/ui/test_f016_{equipment_menu,gate_odds}.gd`, the three menu tests of C22 | AC19, AC20, AC23 (menu part). `EquipmentMenu` (static): `page_count(inventory, page_size)`, `page_of(inventory, id, page_size)`, `entries(inventory, catalog, class_data, base_heal_fraction, can_equip, page, page_size) -> Array[MenuEntry]`, `body(inventory, can_equip) -> String`; ids `sword:<id>`, `equipment_next`, `equipment_previous`, and `ShellMenus`' back id. `Shell` is not touched here |
| T5 | World: `Game` (catalog, seed, equip, sword to rooms, banner), `FloorScene` (loot per room, `pop_taken`, leaving), `Room` (sword, `set_loot`, watch, markers), `TownScene` (sword only), `Player`; the helpers of C22 | `src/world/game.gd`, `src/world/floors/{floor_scene,room,pickup_markers}.gd`, `src/world/town/town_scene.gd`, `src/entities/player/player.gd`, `tests/scenes/{f012_game_test,f015_shell_test,f016_loot_test}.gd`, `tests/scenes/test_f016_{drops,loadout,leave,twins}.gd` | AC13–AC16, AC18, AC24–AC26. Does not call `GateMenu.open` with odds and does not touch `Shell` |
| T6 | Shell wiring and end to end: the Equipment state in `Shell`, equip routing, pages; the gate's odds in the running game (`Game` → `TownScene` → `GateMenu.open`) | `src/world/shell.gd`, `src/world/game.gd`, `src/world/town/town_scene.gd`, `tests/scenes/test_f016_{equipment,gate}.gd` | AC16 (quit to title), AC21–AC23. After T4 and T5 |
| T7 | Lead: one line in `studio/design/combat.md` (the chain's damage comes from the equipped sword), a rendered run with screenshots (drops, banner, the list at 8 and at 17 swords, the gate), the final gate | `studio/design/combat.md`, §8 | AC28; no code |

---

## 7. Plan Review  ·  _Auditor_
<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 6369a90 · **Date:** 2026-11-21 · **Verdict:** CHANGES_REQUESTED ·
**By:** Auditor (lead, D-014)

Two fresh reviewers, read-only, neither told what the other looked for. One read the spec
against the code it names (every line reference of §2, every reader of max HP and of the
dash cooldown, the tests that pin shapes, the task split, the screen fit from the theme's
metrics). The other read it against Lucas's quoted words, recomputed every number from
`data/`, walked 15 sequences through the rules, and looked for exploits and for rules
without a test. Both returned CHANGES_REQUESTED. Findings merged and renumbered.

### PR-1 🔴 `items.md` and `floors.md` contradict C11 and C16  ·  `studio/design/items.md:90-94`, `studio/design/floors.md:127-128`
The design doc says the first win is "the win that clears the floor for the first time",
which §3 rejects, and that a lying sword is lost on Return to town, which C16 takes. The
doc is binding (CLAUDE.md) and no task owned it. Both readings are kinder than Lucas's
words, not contradictions of them, but §3 filed his literal sentence under Rejected without
saying so, and Q2 did not tell him that Return to town takes a sword from across the room.
> **Planner reply (lead):** accepted. `items.md` and `floors.md` now say what C11 and C16
> say; both rows name themselves as the override. §3 quotes his sentence; Q1 and Q2 state
> the difference and what each costs to reverse.

### PR-2 🟡 "Never on the tick the player dies" makes the drops depend on the tick rate  ·  C9, C23
The sim runs 4 combat steps per tick at 30 ticks/s and 1 at 120
(`src/core/combat/combat_sim.gd:74-91`). An enemy killed in step 1 and a player killed in
step 3 share a tick at 30 and not at 120: one rate draws, the other does not, and every
later drop of the character differs. Taking once per tick has the same shape: a dash covers
0.67 tiles per tick at 30, so a pass 0.73 to 0.80 tiles from a drop takes at 120 and can
miss at 30. AC25 would only notice if its script happened to contain such a case.
> **Planner reply (lead):** accepted, and C9 is rewritten rather than patched: the loot is
> attached to the sim (`set_loot`, as the wave director is) and acts at the end of every
> combat step, so nothing about it depends on the tick rate. Deaths are rolled whether or
> not the player is alive; a dead player takes nothing. §3 rejects the per-tick version by
> name. AC14 and AC26 contain both cases.

### PR-3 🟡 The statistical test cannot see an off-by-one  ·  AC9
At 6,000 wins the band for the 30 % sword is 1,658 to 1,942: `randi_range(0, 100)` (1,782)
and `<` for `<=` (1,740 or 1,860) pass. A regular chance computed from 28 kills passes. A
pool pick skewed 25/19/19/19/19 passes. Guaranteed wins had no sample size.
> **Planner reply (lead):** accepted. C10 and C11 name the exact draws and one pure mapping
> function; AC9 tests the mapping over every roll and the draw counts against a reference
> generator; AC10 keeps the statistics, with 6,000 guaranteed wins.

### PR-4 🟡 `FloorRun` refuses its own snapshot after Vitality is taken off  ·  `src/core/floors/floor_run.gd:148`
`from_dict` needs `entry_hp <= _max_hp`; entering the pre-boss room at 105/108 and switching
away leaves an entry HP of 105 against a max of 100. Also unsaid: on a restore the sword
must be set before `from_dict`.
> **Planner reply (lead):** accepted: C15 (clamps down, never raises), C8 (restore order),
> AC18.

### PR-5 🟡 Snapshot rules left unsaid  ·  C9, C13, C14
What `RoomLoot`'s dict holds (the queue? that a drop is a boss's?), who owns it, what
`from_dict` does with an owned id the catalog lacks, and whether the empty inventory of a
session without a catalog is valid.
> **Planner reply (lead):** accepted: C9 (drops carry their source; the queue is empty
> between steps; nothing calls it until save/load, like `FloorRun.to_dict()`), C13 (unknown
> ids and floors refused; the empty state valid), AC12.

### PR-6 🟡 The gate's text area would break a test C22 does not list  ·  `src/ui/town/gate_menu.tscn`, `tests/ui/test_gate_menu.gd:8`
`Panel` is a PanelContainer holding `List`. A label under the list means re-parenting
`List` (the gate's 77 tests address `Panel/List`); a label inside `List` breaks
`tests/scenes/f012_game_test.gd:289-290`. And the panel is centred, so the list would jump
when the focus moves to `Stay in town`.
> **Planner reply (lead):** accepted: C19 puts the odds in a node of their own beside
> `Panel`, anchored to the bottom of the screen; AC23 checks that the list does not move and
> that the gate's tests pass unedited.

### PR-7 🟡 The `Found:` banner is overwritten in the tick it appears  ·  `src/world/floors/floor_scene.gd:183-184`
Taking at the exit is followed, in the same tick, by the next room's heal report, so below
full HP the player never reads what was taken.
> **Planner reply (lead):** accepted: C20 joins the two; AC13.

### PR-8 🟡 `setup()` and F5 against the loadout  ·  `src/core/player/player_motor.gd:99`, `src/entities/player/player.gd:65-66, 87`
`setup()` resets max HP to the class value and is called again by `reset_to_start()`;
`apply_data` receives a fresh `ClassData` that a loadout built from the old one would not
see.
> **Planner reply (lead):** accepted: the motor is given the sword, not a finished loadout,
> and builds the loadout from the class data it holds, again in `setup()` and
> `apply_data()` (C8, AC7).

### PR-9 🟡 Wording a player reads  ·  C18, C19
`Room heal +5%` reads as 5 % more healing; it is 30 % → 35 % of max HP. The gate line had
two percents with two meanings. While the guarantee holds nothing said so clearly, and
nothing said the missing 40 % is "nothing".
> **Planner reply (lead):** accepted: `Room heal 35% of max HP` (base plus bonus, rounded);
> `30% chance: …`; `Your next win is sure to drop one of these.` or `Nothing: 40%`.

### PR-10 🟡 The task split  ·  §6
T5 would call T4's code (`ItemTexts`, `GateMenu.open` with odds); the fixture catalog was
T5's though T2 and T4 need it; AC19 asked for "8 swords and both page entries", which needs
17 swords and the catalog has 15.
> **Planner reply (lead):** accepted: `ItemTexts` and the fixtures move to T1 with pinned
> signatures; the gate's odds in the running game move to T6; AC20 uses a fixture of 17.

### PR-11 🟡 Rules without a test, tests that pass when wrong  ·  §5
No AC for: the weight-size refusal; the sword surviving `setup`/`apply_data`; the draw
counts of C10; "nothing else in core draws"; `minf(1.0, …)`; debug N; the `RoomLoot` round
trip; the gate fitting the screen. AC4 passes with a motor that ignores the sword (the
starter also gives 4/3/9). AC1's monotony is a property of 10:10:22, not of the rule.
> **Planner reply (lead):** accepted: AC1, AC3, AC4 (labelled a data test), AC6 (a sword
> whose hits differ), AC7, AC9, AC12, AC15, AC23, AC27. A boss with an empty table is in C10.

### PR-12 🔵 Smaller gaps
All-zero weights divide by zero; negative bonuses pass; catalog validation runs before the
class data is loaded (`src/world/game.gd:51, 57-58`); a session without `set_loot` needs a
fixed seed; where the page index lives, the focus after a page change, `Back` wired to
`close_settings()`; AC12's boundary had no size; debug N in town reopens the gate without
odds.
> **Planner reply (lead):** accepted, all: C2, C3, C15, C12/C14, C17, AC13, C19.

### PR-13 🔵 For Combat, after play
Juggernaut's Fangs (13/13/20) kills a chaser with four light hits and no finisher (52),
which no other sword does. Mending through the rooms and a switch in the pre-boss room is
the routine the place rule leaves; Vitality there turns five Warden hits into six.
> **Planner reply (lead):** noted in `items.md` IX1. Not changed: the first is inside the
> caps Combat set (light hits up to 13), the second is what "switch before the boss" is for.

**Checked and found sound (both reviewers):** every line reference of §2; the readers of max
HP and of the dash cooldown are complete; reinforcements are built with the room and keep
their `CombatState`, so `watch` reaches every enemy; kills 27/51/38 and chances
3.70/1.96/2.63 %; AC1's table from two separate implementations of the rule; the tie rule
decides at 36, 40, 44, 48 and 49; the 15 swords within the caps, 4/3/9 hits each;
`Tunables.loot_catalog = null` in `F012GameTest.before_each` covers every test that builds a
`Game`, a `Shell` or `main.tscn`; the pinned pause entries, state counts and session keys are
all in C22's files; T2 and T3 are disjoint; with a catalog a sword is always owned and
equipped; no gain from toggling Vitality; the Equipment page (about 275 × 270 px) and the
gate fit the screen by estimate.

**Not checked:** rendered sizes in the engine; `tests/scenes/test_f015_clicks.gd` for
geometry assumptions; `tools/check_core_purity`'s token rules against the new files; whether
`RandomNumberGenerator.new()` self-seeds in 4.7 and how its state restores; nothing was run.

<!-- review-round: 2 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 81e5e5e · **Date:** 2026-11-21 · **Verdict:** APPROVE_WITH_NOTES ·
**By:** Auditor (lead, D-014)

The same two reviewers, read-only, on the amended spec. Both: APPROVE_WITH_NOTES.

**Round 1 findings:** PR-1, PR-2 (the rule), PR-4, PR-5, PR-6, PR-8, PR-9, PR-10, PR-11,
PR-12 ✔ resolved; PR-13 noted. PR-3 and PR-7 partly: PR-15, PR-16 and PR-14 below.

**The new parts against the code (found sound):** `Combatant` gives the `died` signal, the
position and `is_alive()`, so `RoomLoot` needs no other type; the position at the end of a
step is the collision-corrected one at every rate (`move_bodies` runs inside each step,
`src/core/combat/combat_sim.gd:87-89`); the loot's call after `end_step()` conflicts with
nothing; `Room` attaches the waves after everyone is registered and `set_loot` belongs beside
it (`src/world/floors/room.gd:345-349`); the sim's pinned snapshot keys are untouched; C8
fits `reset_to_start()` and F5; `ListMenu` only positions `_panel` and shows or hides the
root, and the gate's tests reach only `Panel/List`; T2 ∥ T3 and T4 ∥ T5 share no file and
call nothing new of each other; no existing test outside C22 breaks by necessity. All 15
sequences of round 1 are defined; two changed: an enemy, or the boss, dying in the same step
as the player is now rolled, the drop lies untaken and the guarantee is kept.

### PR-14 🟡 The banner's join has no mechanism and, for swords taken by leaving, no owner  ·  C20, C16
`Game` shows banners inside signal callbacks and has no tick id; showing them once per tick
instead would break `tests/scenes/test_f012_game.gd:857-861, 878-879`, which read the banner
at once. At the exit `Found:` arrives before the heal. After `take_all()` the old `RoomLoot`
is freed in that tick, so "the scene empties `pop_taken()` each tick" never sees it. No AC
looked at the banner after leaving. A joined text of several names can outgrow the 320 px
label (`src/ui/hud/hud.gd:18`).
> **Planner reply (lead):** accepted: C20 (shown in the callback; parts and physics frame
> kept; the other part first), C16 (who calls `take_all()` reports), C18 (two names and
> ` +N more`), AC15. Walking onto a boss's sword while "Floor cleared" still shows replaces
> it: said in Q3.

### PR-15 🟡 AC14 and AC26 do not pin the phase  ·  §5
"Within the three steps before the death" shares a 30-ticks/s tick only if no tick boundary
falls between; a dash at 0.75 tiles is still taken by a per-tick build in about 84 % of
phases. The build §3 rejects would mostly pass.
> **Planner reply (lead):** accepted: both ACs name the phase, asserted from positions.

### PR-16 🟡 No exact test sees the range of a roll  ·  AC9
The reference-generator check is blind to arguments (`randi_range(0, 100)` and `(1, 100)`
leave the same state), and how many internal steps `randf()` and `randi_range()` take is not
something to count (rejection sampling; none when from equals to).
> **Planner reply (lead):** accepted: the reference makes the same calls with the same
> arguments, and the outcomes of 1,000 kills of each kind must equal those computed from the
> reference's values.

### PR-17 🔵 Deaths fired between ticks, and an enemy rolled twice  ·  C9
The tests' kill helper sets HP outside any step; a waiting reinforcement killed that way
arrives later at full HP and dies again.
> **Planner reply (lead):** accepted: every queued death, one roll per combatant (C9, AC14).

### PR-18 🔵 `set_sword` before `setup()`; PR-19 🔵 the floor entry with Vitality; PR-20 🔵 `take_all()` with a dead player; PR-21 🔵 two `from_dict` edges; PR-22 🔵 wording (the guarantee's proportions, `Nothing: 0%`, the label's cap); PR-23 🔵 the exit check and "death first" are still per tick; PR-24 🔵 no AC for the drawn seed, the focus after a page change, the odds after debug N
> **Planner reply (lead):** accepted, all: C8; C15 and AC18 (also "in a room entered at
> 105", since 108/108 proved nothing); C9, C16, AC14; C13; C18, C19, AC23; C23 names the
> inherited exception and Q1 says "one case" less exactly than that; AC18, AC20, AC23.

**Not checked by either reviewer:** rendered sizes in the engine; whether four
`move_and_slide` calls per tick at 30 ticks/s give the same body positions as one at 120
(existing behaviour, which AC26 relies on); how Godot 4.7's generator restores its state.
The lead reads the last one before T2 starts.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-21  ·  **Branch:** `feature/F-016-loot`

### Progress
- [x] T1 — 7f58afe. Its seven test files: 151 tests, all passing in the lead's run (with
  `test_floor_data.gd` and `test_shipped_tower.gd`: 191); `gdlint`, `gdformat --check`
  (313 files), core purity and the headless boot clean. The implementer broke six refusals
  one at a time (the tie-break, the chain cap, the second-bonus rule, the cooldown epsilon,
  percent < 1, chance > 1) and each failed a test.
- [x] T2 — d2c81a0. Lead's run of the folders it touches: `tests/core/items` 235 tests,
  `tests/core/floors` 603, `tests/core/combat` 182, `tests/core/shell` 34, all passing.
  The implementer made the loot's call run only on the last step of a tick: 5 of the 16 sim
  tests failed, the dash in reach only at steps 6 and 7 among them.
- [x] T3 — 56f0dda (built in a private copy, brought in after T2). Lead's run on the tree
  with both: `tests/core/player` 253 tests, `tests/core/enemies` 409, combat and items as
  above, all passing; `gdlint`, `gdformat --check` (327 files), core purity and the boot
  clean. The implementer broke the motor four ways (no damage passed, the class's cooldown,
  the class's max HP in `setup`, no rebuild in `apply_data`): each failed tests.
- [x] T4 — 5d9426c (built in a private copy, brought in after T5). Lead's run on the tree
  with both: `tests/ui` 340 tests (the gate's 77 unedited among them), `tests/core/shell` 44,
  `test_f015_clicks.gd` 33, and a batch of twelve shell, town and loot scene files 306, all
  passing. Measured by the implementer: the Equipment panel with the middle page of 17 and
  the two-line body is 320 × 287 px at (160, 36.5); the gate with 8 buttons is 160 × 174 at
  (240, 93) and its odds panel 400 × 72 at (120, 280), five lines for every shipped floor.
- [x] T5 — 55e76ca. Lead's run: its four new scene files 47 tests, and nine existing game,
  shell and HUD files 288, all passing. The implementer broke seven of its wirings one at a
  time (no take on advancing, in `leave_floor`, at the boss door; no sword on the room's
  player; no `set_loadout_values`; no banner join; the town ignoring max HP): each failed a
  test.
- [ ] T6
- [ ] T7

### Deviations from plan
- DEV-1 (T4): **`tests/scenes/test_f015_clicks.gd` was edited though C22 does not list it.**
  Its clicks were aimed at pixels ("the top 3 px of the pause menu's Quit to title are the
  confirm's Quit to title"); a fourth pause entry moves every button, and four tests failed.
  The implementer stopped and reported; the lead allowed the edit. Plan review round 1 had
  named this file as not checked. What changed, measured from the real rects: (a) a late
  click on the pause menu's `Quit to title` can no longer land on the quit confirm's confirm
  entry, in town or on a floor (it lands on `Cancel` or on nothing): a new test pins that
  the two rects do not intersect and says the three tests below need twins on `Quit to title`
  again when it fails. (b) On a floor a late click on `Return to town` **can** now land on
  the leave confirm's confirm entry (y 190 to 198). Three tests moved there, renamed:
  `test_a_slow_second_click_without_the_flag_on_quit_to_title_acts_on_the_confirm` →
  `…_on_return_to_town_acts_on_the_confirm`;
  `test_a_triple_click_on_quit_to_title_does_not_quit_and_a_fourth_acts` →
  `test_a_triple_click_on_return_to_town_does_not_leave_and_a_fourth_acts`;
  `test_a_consumed_press_just_after_the_guard_still_holds_off_the_next_on_quit_to_title` →
  `…_on_return_to_town`. (c) Four tests are re-aimed at the overlap of the two entries, read
  at run time and asserted to exist (`_overlap_point_of`): the three town-pause Settings
  tests (Settings over Fullscreen, y 189 to 198; their old point, the centre of Settings, had
  fallen into a 2 px gap, so they had gone blind) and
  `test_a_double_click_on_return_to_town_only_opens_the_confirm`. (d) Four keep their aim
  with a comment that the late click is harmless by today's geometry. (e) Added:
  `test_a_stall_after_the_first_click_on_return_to_town_does_not_leave`, and two tests for a
  rule of F-015 that no test could see broken ("a press during the guard restarts it"):
  `test_an_unflagged_second_click_inside_the_guard_restarts_it_on_settings_from_the_title`
  and `…_on_return_to_town`. The file has 33 tests (29 before). With `MenuPanel` broken four
  ways, one at a time: the guard never starts, 16 fail; the double-click consume removed, 8;
  a press during the guard does not restart it, 2 (none before); a consumed press does not
  restart it, 2. — **Why:** the tests pinned geometry instead of measuring it. — **Impact:**
  no rule of the click guard changed; `menu_panel.gd` is untouched. The accident the guard
  exists for has moved from quitting to leaving a floor (§10 Q5).
- DEV-2 (T4): `ListMenu._move_focus` no longer calls `_set_focus` when the focus is already at
  the end of the list (it grabs the focus again, as before, and the hook is not called);
  `GateMenu` overrides `close()` to hide the odds too. Neither is in C19's words.
- DEV-3 (T5): in the twins test (AC26) the two deaths that must fall in chosen combat steps
  are applied inside those steps by a probe registered on the room's sim (the pattern of
  `WaveFixtures.Recorder`), not by sword hits: a real hit cannot be placed at a chosen step.
  The dash, the roll, the take and the inventory are real. — **Impact:** AC26 proves the
  loot per step in the running game, and the hits' own timing elsewhere.

### Assumptions made (small, reversible)
- ASSUMPTION-18 (T4): the focus hook is called once per real change and once for the focus
  a menu opens with; a mouse takes the focus by a click, not by hovering (a Godot button does
  not focus on hover, and `ListMenu` was not changed to). `EquipmentMenu.body` is the locked
  text first, then `No swords.`, then the choose text. `page_count` counts every owned id,
  also one the catalog does not know (its page can show fewer); a page size below 1 counts
  as 1; a null catalog lists only `Back`. `ShellMenus.focus(EQUIPMENT, …)` is empty: the
  shell takes the focus from the inventory. The `Odds` node is a PanelContainer with one
  wrapping Label; its width (400 px) and bottom margin (8 px) are exports of `GateMenu`.
- ASSUMPTION-19 (T5): a null `Game.loot_catalog` at `_ready` takes `Tunables.loot_catalog`,
  so a game cannot say "no loot" while `Tunables` holds one (the tests null `Tunables`).
  A drawn seed is written back into `Game.loot_seed`. With no catalog no `RoomLoot` is made
  at all (`Room.get_loot()` and the markers are null). The item tunables and the catalog are
  validated only when there is a catalog; a game with setup errors now has its class data
  loaded.
- ASSUMPTION-20 (T5): the banner join applies only when one part is `Found:`; a heal and a
  clear of one physics frame still replace each other, as before; two takes of one frame are
  one notice. `Found:` is shown only while the session says the player is on the floor: a
  pickup in the tick of the death is reported and then hidden by the death pause.
  `src/entities/player/player.gd` needed no change (the motor keeps the sword itself).
- ASSUMPTION-10 (T2): `TowerSession.from_dict` requires the loot key. `CharacterLoot.
  from_dict` is the last step that can fail, so a refusal changes nothing. A session
  snapshot cannot be restored into a session that was not given the same catalog.
- ASSUMPTION-11 (T2): `FloorRun.setup()` resets the heal bonus to 0: the caller calls
  `set_loadout_values` after every `setup()`.
- ASSUMPTION-12 (T2): `take_all()` with no player watched takes everything; it takes
  nothing only when the watched player is dead. Every watched enemy of a boss room is
  rolled as the boss (the data allows one spawn there).
- ASSUMPTION-13 (T2): `RoomLoot.from_dict` accepts a boss floor only when it is 0, or the
  room is the boss room and it is the room's own floor; it needs the catalog to know the
  sword. Which enemies were already rolled is not saved: a restored dead enemy does not
  fire `died` again. `CharacterLoot.from_dict` also refuses a taken-floor list with a
  duplicate or a non-int.
- ASSUMPTION-14 (T2): ids are written to snapshots as `String` and read back as either;
  a drop's position is a `Vector2`. `Inventory.from_dict` emits `changed` once.
  `CharacterLoot.setup` and `TowerSession.set_loot` keep the same `Inventory`, `LootRoller`
  and `CharacterLoot` objects, so listeners keep working.
- ASSUMPTION-15 (T2): additions beyond the spec's list, none against it: `restore_errors()`
  on the four loot classes; `LootRoller.seed_with`, `get_seed`, `get_state`, `sum_of`;
  `CharacterLoot.knows_sword`, `get_catalog`, `get_roller`, `report_taken`;
  `RoomLoot.get_floor_number`, `is_boss_room`; the drop is its own class, `LootDrop`; a
  shared test helper `tests/core/items/loot_fixtures.gd`. `TowerSession` passed gdlint's 20
  public methods and carries a `max-public-methods` disable with its reason, as
  `combatant.gd` does; `CombatSim` is now at exactly 20.
- ASSUMPTION-16 (T2, measured in 4.7.2): `RandomNumberGenerator.new()` seeds itself, so
  `LootRoller` seeds with 0 in `_init`; assigning `seed` rewinds `state`, so a restore sets
  the seed first (a test shows the other order loses the state); `randi_range(0, 0)` does
  not advance the state; `randi_range(1, 100)` and `(0, 100)` leave the same state, which is
  why AC9 also compares outcomes.
- ASSUMPTION-17 (T3): `PlayerMotor.get_loadout()` is null while the motor holds no class
  data (`set_sword` before `setup`); never after. The motor asks the chain which hit comes
  next (`AttackChain.get_start_index(size)`, the rule `start()` itself now uses), so the
  rule exists once. `PlayerMotor` passed 20 public methods and carries the same disable.
- ASSUMPTION-1 (T1): **what a duplicate id is.** The same `SwordData` resource on several
  floors (the shared regular pool) is not one. Refused: two different resources with one id
  anywhere in the catalog, the same sword twice inside one pool or one boss table (it would
  skew the equal pick), and a null entry in either — **Why:** C5 says "a duplicate id"
  and the pool is shared by design.
- ASSUMPTION-2 (T1): a bonus on a Heavy finisher or Quick cuts sword is refused. C3 does not
  list it; "exactly one trait" needs it.
- ASSUMPTION-3 (T1): a null entry in `LootCatalog.floors` means "no loot on that floor"
  (`get_floor_loot` returns null for it).
- ASSUMPTION-4 (T1): the chance per kill is computed by `FloorLoot.get_chance_per_kill(
  floor_data)` (0 for a null floor or no kills); `get_boss_percent_sum()` beside it.
  `get_all_swords()` gives the starter, then each floor's pool, then its boss table, each
  sword once.
- ASSUMPTION-5 (T1): Quickstep's validation allows landing exactly on `min_dash_cooldown`
  with a slack of `SwordData.COOLDOWN_EPSILON` (0.000001): `0.35 − 0.15` is
  `0.19999999999999998` in a double. Not a tunable: it is float slack, like
  `Geometry.DISTANCE_EPSILON`.
- ASSUMPTION-6 (T1): `PlayerLoadout.get_hit_damage(index)` is −1 for a hit the chain does
  not have (what `AttackChain.start` reads as "the attack's own"). `PlayerLoadout.of(class,
  sword, null)` is allowed and means no minimum cooldown. With no cut the class cooldown is
  returned as it is, also below `min_dash_cooldown`, so a game without a sword is `main`.
- ASSUMPTION-7 (T1): `ItemTexts.found_text` of no names is an empty string.
  `ItemTunables.validate()` wants the four caps and the page size `>= 1`,
  `min_dash_cooldown >= 0`, `pickup_radius_tiles > 0`, and refuses NaN.
- ASSUMPTION-8 (T1): a sword whose weights or damage are structurally wrong gets only that
  error; the hit-based checks are skipped for it (they would add noise or pass silently).
- ASSUMPTION-9 (T1): sword ids are the names in snake_case without the apostrophe
  (`wardens_mercy`). `test_sword_math.gd` uses a fixed-seed generator **in the test** for
  AC1's random weights; nothing under `src` draws yet.

### Things the Auditor should look at closely
- **Existing tests edited so far (C22):** `tests/core/floors/test_f015_session.gd`,
  `test_ac5_the_snapshot_keeps_its_keys`: `TowerSession.KEY_LOOT` added to the pinned key
  list (the snapshot has a seventh key). `test_tower_session.gd` needed none.
  `tests/core/shell/test_shell_flow.gd`: `EQUIPMENT`, `open_equipment` and `close_equipment`
  added to its tables, and `test_ac1_the_table_covers_all_13_methods_and_8_start_situations`
  renamed `…_15_methods_and_9_…`. `tests/ui/test_f015_menu_texts.gd`: the two paused-entries
  tests list `Equipment` second, and the focus test skips `EQUIPMENT` as it skips `PLAYING`.
  `tests/scenes/test_f015_shell.gd`: `_pause_entries` only. `tests/scenes/f012_game_test.gd`:
  `Tunables.loot_catalog` nulled before each test and restored after (`f015_shell_test.gd`
  inherits it and needed no edit). `tests/scenes/test_f015_clicks.gd`: DEV-1.

### How to test

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: you said "the first kill of each boss always drops something". It is built as "until you have taken a sword from that boss, every win drops one". The two differ in one case only: the boss dies, his sword lies there, and you die before taking it (a projectile still flying); then the next win is still guaranteed. (And the reverse, as rare: take his sword and die in the same instant, and the sword is yours though the floor is not cleared.) Fine, or the literal rule? One line to change. | no | |
| Q2 | Lead | → Lucas, at Gate B: a sword left lying is taken for you when you walk through the room's exit or choose Return to town (also in the middle of a fight, from across the room), and lost when you die. Fine? If Return to town should lose it instead, the boss guarantee of Q1 has to go back to the literal rule, or a guaranteed drop could be rolled again and again. | no | |
| Q3 | Lead | → Lucas, at Gate B: with more than 8 swords the Equipment list has pages (`equipment_page_size`). The pickup notice shares the one banner: with a heal in the same moment it reads "+30 HP · Found: Twin Edge"; otherwise it replaces what was showing (so walking onto a boss's sword at once replaces "Floor 1 cleared"). | no | |
| Q5 | Lead | → Lucas, at Gate B: with `Equipment` in the pause menu the buttons moved. A late second click on "Quit to title" now lands on "Cancel" or on nothing, never on the confirm; on a floor, a late second click on "Return to town" can land on its confirm. The click guard of F-015 covers it (tested, DEV-1). Please double-click "Return to town" once with a real mouse: it must stop at the question. | no | |
| Q4 | Lead | → Direction: is a menu choice (equip) a player action under G8? It follows the path of Return to town (F-012 §10 Q8 is still open). | no | |

---

## 11. Director Notes  ·  _Lucas_

