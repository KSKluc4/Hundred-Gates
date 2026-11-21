---
id: F-016
title: Basic loot — swords with one trait, drops, the Equipment list (slice 3, second part)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
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
- **How it would work:** the boss always drops on the win that clears the floor.
- **Why rejected:** a drop can be lost after that win (death by a projectile still flying),
  and the guarantee would be gone with nothing taken. It is tied to **taking** a boss sword
  of that floor instead (C11).
- **Tempting because:** `TowerProgress.mark_floor_cleared()` already returns "first time".

### ❌ Rejected: everything in D-017's rejected list
More slots, grid, auto equip, compare popup, switching anywhere, a safe room, loss on death,
Knockback, Opener, speed or reach swords, shop/crafting, random rolls. Not even partially.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | **`SwordData`** (`src/core/items/sword_data.gd`, Resource): `id: StringName`, `display_name: String`, `damage: int`, `weights: PackedInt32Array` (empty = the class chain's own damages), `kind: Kind` (`NONE, HEAVY_FINISHER, QUICK_CUTS, VITALITY, QUICKSTEP, MENDING`), `max_hp_bonus: int`, `dash_cooldown_cut: float`, `room_heal_bonus: float`. `get_hit_damages(class_data) -> PackedInt32Array`. `validate(class_data, rules) -> PackedStringArray`. The 15 swords of `items.md` are `data/items/swords/<id>.tres`, with exactly its numbers. | G9, D-017 |
| C2 | **Split rule.** `SwordMath.split(total, weights) -> PackedInt32Array` (static, `src/core/items/sword_math.gd`): largest remainder in integers, as written in `items.md`; ties to the last hit first, then the earliest. One entry per weight; the entries add up to `total`. Weights of another size than the class chain are a validation error. | Lucas: the rule belongs in the spec; integer HP |
| C3 | **Validation of a sword** refuses: an empty id or name; `damage < 1`; any hit `< 1`; a chain above `max_chain_damage` (49); all hits but the last together above `max_light_hits_damage` (29); the last hit above `max_finisher_damage` (29); `NONE` with weights or any bonus; a utility kind with weights, without its own bonus, or with another kind's bonus; `VITALITY` above `max_hp_bonus_cap` (8); `QUICKSTEP` whose cooldown would fall below `min_dash_cooldown`; `HEAVY_FINISHER` without weights or whose last hit is not above the standard split's; `QUICK_CUTS` without weights or whose last hit is not below the standard split's. "Exactly one trait" is thereby a data rule. | Combat's breakpoints; D-017 |
| C4 | **Tunables** `ItemTunables` (`src/core/tunables/item_tunables.gd`, `data/tunables/items.tres`, `Tunables.ITEM_TUNABLES_PATH`, `Tunables.items`): `max_chain_damage = 49`, `max_light_hits_damage = 29`, `max_finisher_damage = 29`, `max_hp_bonus_cap = 8`, `min_dash_cooldown = 0.2`, `pickup_radius_tiles = 0.8`, `equipment_page_size = 8`. With `validate()`. No such number in code. | G2 |
| C5 | **`FloorLoot`** (Resource): `regular_drops_per_run: float`, `regular_swords: Array[SwordData]`, `boss_swords: Array[SwordData]`, `boss_percents: PackedInt32Array`. **`LootCatalog`** (Resource): `starter_sword`, `floors: Array[FloorLoot]` (index = floor − 1); `get_sword(id)`, `get_all_swords()`, `get_floor_loot(floor_number)` (null when there is none); `validate(tower, class_data, rules)` refuses: no starter; a floor count other than the tower's; a duplicate id; an invalid sword; percents and swords of different sizes; a percent `< 1`; percents adding up above 100; a negative drops-per-run; drops per run on a floor with no kill before the boss; a chance per kill above 1. Shipped: `data/items/loot_catalog.tres` and `data/items/floor_<n>_loot.tres` with `items.md`'s tables; `Tunables.LOOT_CATALOG_PATH`, `Tunables.loot_catalog`. | G9, G5 |
| C6 | **Chance per kill** of a floor = `regular_drops_per_run / FloorData.get_regular_kill_count()` (new method: the kill targets of every room that is not the boss room, added up). It is never a number in data. | Lucas: tuned per floor run |
| C7 | **`PlayerLoadout`** (RefCounted): `PlayerLoadout.of(class_data, sword, rules)`; `sword` may be null. `get_hit_damage(index)` (the sword's split, or the class attack's own damage), `get_max_hp()` (class + bonus), `get_dash_cooldown()` (`maxf(rules.min_dash_cooldown, class − cut)`, or the class value with no cut), `get_room_heal_bonus()`, `get_sword()`. With a null sword every value is the class's: **a game without a sword behaves exactly as `main`**. | No regression; one place for the arithmetic |
| C8 | **The motor reads the loadout.** `PlayerMotor.set_loadout(loadout)` (null = class values): max HP through `CombatState.set_max_hp` (no heal, clamps down); the cooldown read in `_end_dash()`; `_fire_attack()` passes the hit's damage to `AttackChain.start(chain, direction, damage := -1)`, which writes it into its latched copy only (negative = the attack's own). `apply_data()` (F5) keeps the loadout. Windup, active, recovery, arc, range and knockback are never touched. No new snapshot key in `PlayerMotor`, `AttackChain` or `CombatState`: the loadout is setup data, like `ClassData`. | Pillar 2; G7 pattern |
| C9 | **`RoomLoot`** (RefCounted, one per room): `watch(combat_state, position_source)` for every enemy that counts toward the kill target; deaths are queued in the order `died` fires. `resolve()` rolls for the queued deaths in that order and creates the drops at each enemy's position at that moment. `take_near(player_position_tiles) -> Array[StringName]` takes every drop within `pickup_radius_tiles` (centre to centre, inclusive) in the order they dropped; `take_all()` takes the rest. Taking adds to the inventory. `get_drops()` for drawing. `to_dict()`/`from_dict()` hold the lying drops. **The scene calls `resolve()` then `take_near()` once per physics tick, after the combat step, and never on or after the tick the player dies.** | G6, G1, determinism |
| C10 | **Regular kill:** one draw decides whether (`chance per kill`); only on a yes, a second draw picks the sword from the floor's pool, each equally likely. The boss room's enemy never rolls as a regular kill. A floor without `FloorLoot`, an empty pool or zero drops per run rolls nothing and draws nothing. | D-017 |
| C11 | **Boss kill:** if the character has not yet **taken** a boss sword of this floor, the boss always drops one: sword `i` with probability `percent_i / sum`. Otherwise one roll in 100: sword `i` at `percent_i`, nothing for the rest. The flag is set when a sword that this floor's boss dropped is taken, not when it drops. | Lucas: "first win always drops, repeats 60%"; see §3 |
| C12 | **`LootRoller`**: one seeded `RandomNumberGenerator` per character. `to_dict()` holds its seed and state; `from_dict()` restores them so the following draws are identical. Draws use integers for picks (`randi_range`) and one `randf()` for the regular yes/no. Nothing else in `src/core` draws. | G7; co-op later |
| C13 | **`Inventory`** (RefCounted): `add(id)`, `get_count(id)`, `has(id)`, `get_ids()` (order of first acquisition), `equip(id) -> bool` (only an owned sword; equipping the equipped one is a yes that changes nothing), `get_equipped_id()`, signal `changed`, `to_dict()`/`from_dict() -> bool` (refuses a count `< 1`, an equipped id that is not owned, wrong types). **`CharacterLoot`** (RefCounted) owns the inventory, the roller, the catalog and the floors whose boss sword was taken; `setup(catalog, seed)` gives and equips the starter (a null catalog gives nothing and makes every roll a no); `get_inventory()`, `get_equipped_sword()`, `make_room_loot(floor_number, floor_data, room_index, rules)`, `to_dict()`/`from_dict()`. | G7 |
| C14 | **`TowerSession`** owns one `CharacterLoot`, created in `setup()` with no catalog, left alone by `_clear_visit()`, in `to_dict()`/`from_dict()`. `set_loot(catalog, seed)`, `get_loot()`. **`can_equip(pre_boss_room_cleared: bool) -> bool`**: true in `TOWN`; in `FLOOR` the fact passed in; false in `DEATH_PAUSE`. **`equip_sword(id, pre_boss_room_cleared) -> bool`** refuses when `can_equip` is false or the sword is not owned. `FloorRun.is_pre_boss_room_cleared()` is true when the current room is the one before the boss room and is cleared. `Game` only passes the fact on (F-015/C5: it decides nothing). | Lucas: town and cleared last room only |
| C15 | **World.** `Game.loot_catalog` (default `Tunables.loot_catalog`; read once in `_ready`; null = no loot) and `Game.loot_seed` (0 = one is drawn at `_ready`). A catalog with validation errors is a setup error like the others (`get_setup_errors()`), and nothing is built. `Game.can_equip_sword()`, `Game.equip_sword(id) -> bool`: on a yes the loadout of the player now on screen and of the running `FloorRun` change at once. Every room's player is built with the current loadout, **before** the entry HP is applied. `FloorRun.set_loadout_values(max_hp, room_heal_bonus)`; the heal is `roundi(max_hp × minf(1.0, fraction + bonus))`; the boss room's full heal and a floor entry use the loadout's max HP. The town player has the loadout's max HP. | C7 applied |
| C16 | **Leaving a room.** Walking through the exit (also the boss room's door) and Return to town take what lies in the room (`take_all()`) before the room is freed. Death takes nothing: untaken swords are gone with the room. Debug R (restart room) and debug N drop what lies there. | A boss's sword is not lost by oversight |
| C17 | **Equipment menu.** `ShellFlow.State.EQUIPMENT` (added last in the enum), `open_equipment()` (from `PAUSED`), `close_equipment()`, `back()` returns to `PAUSED`, `is_game_paused()` is true. The pause menu gets `Equipment` as its second entry, on a floor and in town. Entries, in order: the owned swords of the page (order of first acquisition), `Next page` and `Previous page` when there is one, `Back`. A page holds `equipment_page_size` swords. Opening shows the page of the equipped sword with the focus on it. A sword's entry: `<name> — <damage> (<h1>/<h2>/<h3>) — <trait>`, then ` ×<n>` when `n > 1`, then ` [equipped]`. Where equipping is not allowed every sword entry is disabled and the body says where it is. Choosing a sword calls `Game.equip_sword`; on a yes the two entries change **in place** (`set_entry_text`): no `open()`, the focus stays, the guard does not restart. Changing page is an `open()`. | Lucas: a list, no grid; F-015 DEV-11 |
| C18 | **Texts** in one file, `src/ui/items/item_texts.gd` (static): heading `Equipment`; bodies `Choose a sword to equip it.`, `Swords can be changed in town, or in the last room before a boss once it is cleared.`, `No swords.`; traits `No trait`, `Heavy finisher`, `Quick cuts`, `Max HP +%d`, `Dash cooldown -%.2f s`, `Room heal +%d%%`; `Next page`, `Previous page`; banner `Found: %s` (names joined by `, `); gate lines (C19). The pause entry's text and id live in `ShellMenus` with the others. No item string anywhere else. | F-012/C16 |
| C19 | **Odds at the gate.** Under its list `GateMenu` shows, for the floor whose entry has the focus: `Boss drops:`, one line per sword `<percent>%  <sword entry text without count and mark>`, and `Your next win is sure to drop one.` while that floor's boss sword has not been taken. Nothing for `Stay in town` or a floor without a table. `ListMenu` gets one hook, `_focus_moved(index)`, empty in the base, called where the focus changes; `GateMenu.open(entries, odds_by_floor := {})`. The texts are built by `ItemTexts`; `Game` hands them to `TownScene`. | Lucas: "the player can see those odds"; approved at the gate |
| C20 | **Pickup notice and drops on screen.** Taking shows the HUD banner (`Found: …`, `Tunables.tower.banner_duration`); it replaces the banner showing, as every banner does. A drop is drawn by a `Room` child from `RoomLoot.get_drops()` (the `WaveMarkers` pattern), a placeholder shape whose size and colour are exports of that node; it reads no core state but the drops. | G6; Art owns the look (IX3) |
| C21 | **Core purity and data.** Everything in `src/core/items/` is RefCounted or Resource, no Node, no texture, no scene. No third-party code. Item paths are constants tagged `# G5`. | G4, G5, G6 |
| C22 | **Existing tests.** The shared helpers set `Tunables.loot_catalog = null` before each test and restore it after (the existing pattern for `Tunables`), so every existing test runs without loot. These files may be edited, each edit listed in §8 with its reason: `tests/core/shell/test_shell_flow.gd` (states, methods, situations), `tests/ui/test_f015_menu_texts.gd` and `tests/scenes/test_f015_shell.gd` (the pause menu's entries), `tests/core/floors/test_f015_session.gd` and `tests/core/floors/test_tower_session.gd` (snapshot keys), `tests/scenes/f012_game_test.gd`, `tests/scenes/f015_shell_test.gd` (helpers). No test is deleted without a replacement. **All other tests stay green unedited**; if one cannot, stop and log it before touching it. | F-015/C18; an unlisted edit is a 🔴 |
| C23 | **Determinism.** Two sessions with the same seed, catalog and sequence of calls give the same drops and the same snapshots, tick for tick, at 30, 60 and 120 physics ticks per second. A snapshot taken at any tick and restored into a fresh session continues identically. | G1, G7 |

**Must not break:** every F-001 to F-015 behaviour; the whole suite (2,579 tests on `main`);
with no catalog the game is `main`; boss fights at the starter sword are unchanged to the
tick; F-015's pause rules (C2 guard, C6 for a pause without an equip, the choose guard);
`gdlint`, `gdformat --check`, `tools/check_core_purity`, a clean headless boot.

---

## 5. Acceptance Criteria  ·  _Planner_

- [ ] AC1: `SwordMath.split(d, [10, 10, 22])` gives 9/8/19, 9/9/19, 9/9/20, 9/9/21, 10/9/21,
  10/10/21, 10/10/22, 10/10/23, 11/10/23, 11/11/23, 11/11/24, 11/11/25, 12/11/25, 12/11/26
  for `d` = 36 … 49; every hit is non-decreasing in `d`; the hits always add up to `d`.
- [ ] AC2: each of the 15 shipped swords loads, validates, and has exactly the damage, hits
  and trait value of `items.md`; the shipped catalog validates against the shipped tower and
  class; its three boss tables and its regular pool are `items.md`'s.
- [ ] AC3: each refusal of C3 and of C5 has a test that fails without it.
- [ ] AC4: against the shipped enemy data every shipped sword kills a chaser in 4 hits, a
  caster in 3 and a brute in 9, starting the chain fresh (computed in a test from the data).
- [ ] AC5: with a null sword `PlayerLoadout` returns the class's values, and a fight run with
  `set_loadout(null)`, with no call at all, and with the starter sword gives identical
  snapshots at every tick.
- [ ] AC6: with a sword equipped, the three hits deal its three damages to an enemy; windup,
  active, recovery, arc, range and knockback of each hit are those of the class attack; the
  shared `AttackData` and `ClassData` are unchanged after the fight.
- [ ] AC7: Vitality: max HP is class + 8; setting the loadout does not heal; switching to a
  sword without it clamps HP to the class max. Quickstep: the cooldown after a dash is the
  class value minus the cut, never below `min_dash_cooldown`. Mending: the room-clear heal is
  `roundi(max_hp × (fraction + bonus))` and follows a changed `room_clear_heal_fraction`.
- [ ] AC8: the chance per kill of the shipped floors is 1/27, 1/51 and 1/38 (from
  `get_regular_kill_count()` = 27, 51, 38); changing a room's kill target changes the chance
  and not the drops per run.
- [ ] AC9: with a fixed seed, 20,000 regular kills at chance `p` drop within 4 standard
  deviations of `20,000 × p`, each pool sword within 4 of an equal share; 6,000 repeat boss
  wins give each sword within 4 standard deviations of its percent and nothing for the rest;
  first wins never give nothing and keep the 3 : 2 : 1 proportions.
- [ ] AC10: the boss guarantee holds until a boss sword of that floor is **taken**: a drop
  left behind by a death keeps the next win guaranteed; after one is taken the next win rolls
  the percentages. Other floors' flags are untouched.
- [ ] AC11: same seed and calls → same drops and equal snapshots; another seed → different
  drops; a session saved with `to_dict()` at any point of a scripted run and restored into a
  fresh one gives the same later drops (C12, C23). `from_dict` refuses each malformed shape
  of C13 and leaves the state as it was.
- [ ] AC12: in a room a killed enemy's drop appears at its position on the tick's `resolve()`,
  not before; walking within the radius takes it (inclusive at exactly the radius, not one
  step outside); the inventory count rises; the banner says `Found: <name>`. Two drops in
  reach are taken in drop order and named in one banner.
- [ ] AC13: on the tick the player dies and after it nothing is rolled or taken; the drops
  lying in the room are not in the inventory after the death is confirmed.
- [ ] AC14: walking through an exit, the boss door, and Return to town each take what lies
  in the room; debug restart does not.
- [ ] AC15: a new game owns the Recruit's Sword ×1, equipped; death, Return to town and
  clearing a floor keep the inventory and the equipped sword; quit to title and Start again
  give a fresh one. A second pickup of an owned sword shows `×2`.
- [ ] AC16: `can_equip`/`equip_sword` say yes in town; on a floor only in the cleared room
  before the boss (not in that room before it is cleared, not in an earlier cleared room, not
  in the boss room cleared or not, not during the death pause); never for a sword not owned.
- [ ] AC17: equipping in town changes the town player's max HP and, on the next floor, the
  hits, cooldown and heal; equipping in the cleared pre-boss room changes the player on
  screen at once and the boss room is entered at the new max HP.
- [ ] AC18: `ShellFlow`: `EQUIPMENT` is reached only from `PAUSED`, `back()` and
  `close_equipment()` return to `PAUSED` with the focus on `Equipment`; the game stays
  stopped; Escape, pad B and pad Start behave as in `SETTINGS`. Every other transition of
  F-015 is unchanged.
- [ ] AC19: the Equipment menu shows the entries of C17 with the exact texts of C18; with 9
  owned swords and a page size of 8 there are two pages, `Next page` / `Previous page` appear
  only where there is one, and the menu opens on the equipped sword's page with the focus on
  it; the whole panel is inside the 640 × 360 screen with 8 swords and both page entries.
- [ ] AC20: where equipping is allowed, choosing a sword equips it, the `[equipped]` mark
  moves, the focus stays, the panel was not reopened (the choose guard did not restart); the
  equipped sword chosen again changes nothing. Where it is not allowed the sword entries are
  disabled, nothing can be chosen by key, pad, click or `choose()`, and the body says where.
- [ ] AC21: a pause with no equip leaves the game's snapshots equal before and after (F-015
  AC15 still passes unedited); after a pause with an equip, the two-tick input guard and the
  physics space behave as in F-015.
- [ ] AC22: at the gate, focusing a floor shows its boss's three swords with their percents
  and, while none was taken, the guarantee line; after one is taken the line is gone;
  `Stay in town` shows nothing; the gate works as before by key, pad and click, and with no
  catalog it shows no odds area text at all.
- [ ] AC23: drops are drawn where they lie and disappear when taken; the marker node reads
  only `RoomLoot.get_drops()`.
- [ ] AC24: with `Tunables.loot_catalog = null` the full suite of `main` passes with only the
  edits C22 lists; a catalog with an error makes `Game` report it in `get_setup_errors()` and
  the title shows the start failure, as for the other data.
- [ ] AC25: 30, 60 and 120 ticks per second give the same drops, pickups and inventory for a
  scripted run through a fixture floor (same seed), compared tick for tick in game time.
- [ ] AC26: `gdlint src tests`, `gdformat --check src tests`, `tools/check_core_purity` and
  the headless boot are clean; nothing is left in `user://` by the suite.

**How to verify manually (Lucas, Gate B):** start a game; pause in town: `Equipment` lists
the Recruit's Sword, equipped. Walk to the gate: floor 1 shows the Warden's three swords and
the guarantee line. Clear floor 1: a sword now and then lies where an enemy died; walk over
it and read the banner. In the last room before the Warden, clear it, pause, open
`Equipment`, switch swords; try the same one room earlier (the list is grey). Beat the
Warden: he always leaves a sword the first time. Die on floor 2: the swords are still there.

---

## 6. Task Breakdown  ·  _Planner_

One commit per task. T2 ∥ T3 and T4 ∥ T5 have disjoint file lists.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Data and arithmetic: `SwordData`, `SwordMath`, `ItemTunables`, `FloorLoot`, `LootCatalog`, `PlayerLoadout`, `FloorData.get_regular_kill_count()`; the 15 swords, three floor tables, the catalog, the tunables file; `Tunables` paths and preloads | `src/core/items/{sword_data,sword_math,floor_loot,loot_catalog,player_loadout}.gd`, `src/core/tunables/item_tunables.gd`, `src/core/floors/floor_data.gd`, `src/autoload/tunables.gd`, `data/items/**`, `data/tunables/items.tres`, `tests/core/items/test_{sword_math,sword_data,loot_catalog,player_loadout,shipped_items}.gd`, `tests/core/test_item_tunables.gd` | AC1–AC4, AC5 (loadout part), AC8. `.gitkeep` in `data/items` goes |
| T2 | Loot state: `Inventory`, `LootRoller`, `CharacterLoot`, `RoomLoot`; `TowerSession` and `FloorRun` additions | `src/core/items/{inventory,loot_roller,character_loot,room_loot}.gd`, `src/core/floors/{tower_session,floor_run}.gd`, `tests/core/items/test_{inventory,loot_roller,character_loot,room_loot}.gd`, `tests/core/floors/test_f016_{session,floor_run}.gd`, the two session tests of C22 | AC7 (heal), AC9–AC11, AC16, core parts of AC12–AC14 |
| T3 | The motor reads the loadout: `set_loadout`, the damage argument of `AttackChain.start`, cooldown, max HP | `src/core/player/{player_motor,attack_chain}.gd`, `tests/core/player/test_f016_loadout.gd` | AC5–AC7 |
| T4 | Menus without the world: `ShellFlow.EQUIPMENT`, the pause entry, `ItemTexts`, the Equipment entries builder with pages, the `ListMenu` hook and the gate's odds area | `src/core/shell/shell_flow.gd`, `src/ui/menus/{shell_menus,list_menu}.gd`, `src/ui/items/{item_texts,equipment_menu}.gd`, `src/ui/town/gate_menu.{gd,tscn}`, `tests/ui/test_f016_{item_texts,equipment_menu,gate_odds}.gd`, the three menu tests of C22 | AC18, AC19, texts of AC20, AC22 (menu part). Needs T2's `Inventory` |
| T5 | World: `Game` (catalog, seed, equip, loadout to rooms, banner), `FloorScene` (resolve, take, leave), `Room` (loadout, watch, markers), `TownScene` (loadout, odds texts), `Player`; the helpers of C22; a fixture catalog | `src/world/{game}.gd`, `src/world/floors/{floor_scene,room,pickup_markers}.gd`, `src/world/town/town_scene.gd`, `src/entities/player/player.gd`, `tests/core/items/item_fixtures.gd`, `tests/scenes/{f012_game_test,f015_shell_test,f016_loot_test}.gd`, `tests/scenes/test_f016_{drops,loadout,leave,twins}.gd` | AC12–AC15, AC17, AC23–AC25 |
| T6 | Shell wiring and end to end: the Equipment state in `Shell`, equip routing, pages, the gate's odds in the running game | `src/world/shell.gd`, `tests/scenes/test_f016_{equipment,gate}.gd` | AC20–AC22, AC15 (quit to title). After T4 and T5 |
| T7 | Lead: one line in `studio/design/combat.md` (the chain's damage comes from the equipped sword), a rendered run with screenshots (drops, banner, the list, the gate), the final gate | `studio/design/combat.md`, §8 | AC26; no code |

---

## 7. Plan Review  ·  _Auditor_

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-016-loot`

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7

### Deviations from plan

### Assumptions made (small, reversible)

### Things the Auditor should look at closely

### How to test

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: "first win always drops" is built as "until you have taken a sword from that boss, every win drops one", so a drop lost to a death is not the end of the guarantee. Fine? | no | |
| Q2 | Lead | → Lucas, at Gate B: a sword left lying is taken for you when you walk through the room's exit or choose Return to town, and lost when you die. Fine, or should a death keep it too? | no | |
| Q3 | Lead | → Lucas, at Gate B: with more than 8 swords the Equipment list has pages (`equipment_page_size`). The pickup notice uses the one banner, so it can replace "+30 HP". | no | |
| Q4 | Lead | → Direction: is a menu choice (equip) a player action under G8? It follows the path of Return to town (F-012 §10 Q8 is still open). | no | |

---

## 11. Director Notes  ·  _Lucas_

