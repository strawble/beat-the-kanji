# Beat the Kanji

> *Learn Japanese kanji by fighting monsters — one correct answer at a time.*

---

## Table of Contents

- [Overview](#overview)
- [Current State](#current-state)
- [Gameplay](#gameplay)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Direction for Future Contributors](#direction-for-future-contributors)
- [Team](#team)
- [License & Credits](#license--credits)

---

## Overview

**Beat the Kanji** is a single-player idle RPG built in **Godot 4** that uses combat mechanics to make learning Japanese kanji feel like a game. Players fight procedurally generated bosses by answering multiple-choice questions about kanji — their English meaning, character form, kun'yomi or on'yomi reading. Correct answers deal damage to the boss; wrong answers or timeouts let the boss hit back.

The core learning loop is built around **mastery tracking**: every kanji has a persistent score from 0.0 to 1.0. Kanjis you struggle with appear more often in boss pools; kanjis you know well fade into the background. Progress through four zones unlocks increasingly advanced kanji pools, keeping you challenged as you improve.

The project started as a learning exercise for Godot 4 game development and grew into a feature-complete prototype. The core gameplay loop, all systems, and the overall architecture are solid and working. **What the game needs now is content, polish, and visual identity** — see the [Direction for Future Contributors](#direction-for-future-contributors) section.

---

## Current State

> **Version:** v2 — pre-alpha, feature-complete core, placeholder visuals.

### What is implemented and working

**Combat system**
- Full question loop: MCQ (4 choices) → answer → damage to boss / damage to player
- Four question types per kanji: meaning, character, kun'yomi, on'yomi
- Adaptive response timer: shorter for mastered kanjis (min 5s), longer for unfamiliar ones (max 12s)
- Critical hits (rate + damage multiplier), dodge chance, HP regeneration per correct answer
- Damage reduction from armor, revive shield consumable

**Hint system**
- 3 progressive levels per question: stroke count → first letter of the answer → full reveal + 2 wrong choices eliminated
- Using hints reduces the mastery gain on a correct answer

**Parry / drawing system**
- Every ~20 seconds, the boss telegraphs a big attack; a drawing overlay appears
- Player traces the kanji from memory on a 300×300 canvas
- 3 attempts with progressively less visual guidance (bright watermark → faded → minimal)
- Scoring: 4×4 coverage grid (40% threshold to succeed)
- Successful parry triggers a counter-attack; failure deals double damage

**Progression**
- Player levels (XP per fight, scales with level)
- 45 kanji unlocked across levels 1–15 (all in Zone 1)
- 4 zones defined with level/coin requirements (content only written for Zone 1)
- Persistent mastery tracking per kanji (saved to disk)

**Shop (5 tabs)**
- Weapons (8), Armor (7), Accessories (7), Consumables (6): 28 items total
- 3 tiers: common, rare, epic
- 2 equipment sets: Samurai Set, Scholar's Way (3-piece bonus each)
- 6 permanent stat upgrade lines (Strength, Vitality, Crit Rate, Crit Damage, Dodge, Regen), 10 levels each, exponential cost scaling

**Navigation**
- Global NavBar (CanvasLayer, layer 100) with 4 tabs: Battle / Map / Shop / KanjiDex
- World Map with zone unlock/purchase flow
- KanjiDex with zone filter and 1–3 mastery stars per card
- Help screen (full gameplay explanation)
- Credits screen (placeholder names)

**Infrastructure**
- Save/load via Godot `Resource` serialization (`user://save.tres`)
- 7 autoload singletons (GameManager, KanjiDB, ItemDB, ZoneManager, BossGenerator, AudioManager, NavBar)
- Data-driven design: kanjis, items, zones all defined in JSON

### What is missing / placeholder

| Area | Status |
|---|---|
| Visual assets | None — Godot default styles everywhere, no custom UI art |
| Boss visuals | A `Label` showing the kanji character — no sprite |
| Zone backgrounds | Field exists in `zones_data.json`, no images yet |
| Kanji content | 45 kanjis (Zone 1 only); Zones 2–4 are structurally ready but empty |
| Item/shop icons | No icons; text-only rows |
| Sound & music | `AudioManager` exists as a stub; completely silent |
| Parry recognition | Coverage-grid heuristic only; no stroke order, no shape matching |
| Animations | No `AnimationPlayer` sequences, no particles, no tweens on combat events |
| Settings screen | No audio volume, no save management, no display options |

---

## Gameplay

### Core loop

```
Enter zone → Boss generated (level + zone + inverse-mastery weighting)
           → MCQ question with countdown timer
           → Correct → deal damage (+ possible crit)  → mastery +0.15
           → Wrong / timeout → take damage (- possible dodge)  → mastery -0.10
           → Every ~20s: PARRY → draw the kanji to counter
           → Boss HP = 0 → XP + coins + victory screen → new boss
           → Player HP = 0 → lose coins → new boss
```

### Questions

Each question is randomly typed:
- **Meaning** — "What does 日 mean?" → `sun` / `moon` / `fire` / `water`
- **Character** — "Which kanji means 'fire'?" → `火` / `水` / `木` / `土`
- **Kun'yomi** — "Kun'yomi of 山?" → `やま` / `かわ` / `ひと` / `つち`
- **On'yomi** — "On'yomi of 月?" → `ゲツ` / `カ` / `スイ` / `ジン`

Wrong choices are drawn from the unlocked kanji pool — they are always plausible, never random noise.

### Mastery & spaced repetition

Every kanji has a mastery value in `[0.0, 1.0]`. Boss kanji pools are weighted inversely: a kanji with mastery 0.1 has ~10× the weight of one with mastery 0.9. This creates a natural SRS-like loop without an explicit scheduler.

The KanjiDex shows each kanji's mastery as stars:

| Stars | Mastery | Approximate answers needed |
|-------|---------|---------------------------|
| ☆☆☆ | < 0.30 | fewer than ~2 correct |
| ★☆☆ | 0.30–0.59 | ~2–4 correct |
| ★★☆ | 0.60–0.89 | ~4–6 correct |
| ★★★ | ≥ 0.90 | ~6+ correct in a row |

### Zones

| Zone | Level | Cost | Kanji range |
|---|---|---|---|
| Yamato Plains | 1 | Free | Levels 1–15 (45 kanjis, fully written) |
| Kazan Desert | 26 | 500 🪙 | Levels 26–50 (structure ready, no content) |
| Arashi Mountains | 51 | 1 200 🪙 | Levels 51–75 (structure ready, no content) |
| Homura Volcano | 76 | 2 500 🪙 | Levels 76–100 (structure ready, no content) |

### Equipment sets

| Set | Pieces needed | Bonus |
|---|---|---|
| Samurai Set | 3 | +20 damage, +10% dodge |
| Scholar's Way | 3 | +15% crit rate, +5 HP regen/answer |

---

## Architecture

### Design principles

The codebase follows three principles that any contributor should maintain:

1. **Data-driven** — kanjis, items, and zones live in JSON files. Adding content means editing JSON, not touching scripts.
2. **Autoload singletons** — all cross-scene state and logic lives in named singletons registered as Godot autoloads. Scenes never hold persistent state themselves.
3. **Flat stat calculation** — player stats are never cached; `GameManager.get_stat(name)` computes `upgrades + equipment + set bonuses` on every call. This means equipping an item is a one-liner with no invalidation logic.

### Autoloads

| Singleton | Responsibility |
|---|---|
| `GameManager` | Save/load, XP, coins, mastery, equipment, upgrades, all stat getters |
| `KanjiDB` | Load and query `kanji_data.json`; build MCQ questions and hints |
| `ItemDB` | Load and query `items_data.json`; set definitions, tier colors |
| `ZoneManager` | Load and query `zones_data.json`; unlock/activate flow |
| `BossGenerator` | Procedurally create a boss dict (name, HP, damage, kanji pool, rewards) |
| `AudioManager` | Stub — `play_sfx(name)` and `play_music(name)`, both no-ops for now |
| `NavBar` | CanvasLayer (layer 100) — builds the bottom nav bar; each scene calls `NavBar.show_for_scene("key")` |

### Stat calculation

```
effective_stat("crit_rate")
  = _stat_from_upgrades("crit_rate")    # upgrade level × 2.0
  + _stat_from_equipment("crit_rate")   # sum of effects on equipped items
  + _stat_from_sets("crit_rate")        # active set bonuses
```

### Scene layer order

```
layer 100  NavBar (autoload, always visible in-game)
layer  60  VictoryScreen overlay
layer  50  KanjiDrawing parry overlay
layer   0  Scene CanvasLayer (normal UI)
```

---

## Project Structure

```
res://
├── autoloads/
│   ├── GameManager.gd     # Central state, stats, save/load
│   ├── KanjiDB.gd         # Kanji queries, MCQ generation, hints
│   ├── ItemDB.gd          # Item queries, sets, tier colors
│   ├── ZoneManager.gd     # Zone unlock/activate logic
│   ├── BossGenerator.gd   # Procedural boss creation
│   ├── AudioManager.gd    # SFX/music stub (no-op)
│   └── NavBar.gd          # Global navigation bar
│
├── data/
│   ├── kanji_data.json    # 45 kanjis (zone 1) with stroke_count and first_stroke_hint
│   ├── items_data.json    # 28 items, 2 sets, effects array
│   └── zones_data.json    # 4 zones with unlock rules and asset hooks
│
├── fonts/
│   ├── animeace2_reg.ttf              # Latin / UI text (Anime Ace 2)
│   ├── Aiharahudemojikaisho_free305.ttf  # Japanese kanji & kana (Aihara Hudemoji Kaisho)
│   └── font_composite.tres            # FontVariation: Anime Ace 2 base + Aihara fallback
│
├── themes/
│   └── main_theme.tres    # Global theme — applies font_composite project-wide
│
├── resources/
│   └── PlayerData.gd      # Serializable Resource (save file schema)
│
└── scenes/
    ├── main_menu/         # MainMenu — Play, World Map, KanjiDex, How to Play, Credits
    ├── help/              # Help — scrollable gameplay explanation
    ├── credits/           # Credits — placeholder team names
    ├── game_world/        # GameWorld (combat), CombatTimer
    ├── kanji_drawing/     # KanjiDrawing — parry drawing overlay
    ├── shop/              # Shop (5 tabs), ItemRow, StatUpgradeRow
    ├── kanji_dex/         # KanjiDex (zone filter + mastery stars), KanjiCard
    ├── victory/           # VictoryScreen
    └── world_map/         # WorldMap, ZoneCard
```

---

## Getting Started

### Requirements

- [Godot 4.2+](https://godotengine.org/download)
- No plugins or addons required

### Setup

```bash
git clone https://github.com/[PLACEHOLDER_ORG]/beat-the-kanji.git
```

Open in Godot: **File → Open Project → select the project folder**.

Before running, verify these three settings:

**Autoloads** (`Project → Project Settings → Autoload`), in this order:

| Name | Path |
|------|------|
| GameManager | `res://autoloads/GameManager.gd` |
| KanjiDB | `res://autoloads/KanjiDB.gd` |
| ItemDB | `res://autoloads/ItemDB.gd` |
| ZoneManager | `res://autoloads/ZoneManager.gd` |
| BossGenerator | `res://autoloads/BossGenerator.gd` |
| AudioManager | `res://autoloads/AudioManager.gd` |
| NavBar | `res://autoloads/NavBar.gd` |

**Global theme** (`Project → Project Settings → GUI → Theme → Custom`):
`res://themes/main_theme.tres`

**Main scene** (`Project → Project Settings → Application → Run → Main Scene`):
`res://scenes/main_menu/MainMenu.tscn`

Press **F5**. The console should print:
```
GameManager: new game.
KanjiDB: 45 kanjis loaded.
ItemDB: 28 items, 2 sets loaded.
ZoneManager: 4 zones loaded.
```

### Dev shortcuts (in GameWorld)

| Key | Action |
|-----|--------|
| `T` | +50 XP |
| `C` | +200 coins |
| `H` | use a potion (if owned) |
| `P` | force a parry immediately |
| `R` | full save reset |

---

## Direction for Future Contributors

The core of the game is complete. The loop is fun. The systems talk to each other correctly. What's missing is everything that makes a game *feel* like a game rather than a prototype — art, sound, content, and interaction depth. Here is a prioritised list of what needs to happen next.

### 1. Visual identity (highest priority)

The game currently runs on Godot's default grey UI. This is the single biggest gap between "working prototype" and "something you'd want to show to someone."

**What to do:**
- Design a visual theme — the game has a clear setting (feudal Japan × RPG). Think ink wash, parchment, brushstroke UI elements.
- Apply custom `StyleBoxTexture` or `StyleBoxFlat` overrides to the global `main_theme.tres`. Every `PanelContainer`, `Button`, `ProgressBar` inherits from it.
- Create boss sprites — currently a `Label` showing the kanji character. There's a `boss_sprite_theme` field per zone in `zones_data.json` (`nature`, `fire`, `ice`, `lava`) to guide the art direction. Swap the `Label` for a `TextureRect` in `GameWorld.tscn`.
- Create zone backgrounds — the `background_texture` field in `zones_data.json` is already wired up in `GameWorld.gd`. Drop a `.png` per zone into `res://assets/backgrounds/` and they'll appear automatically.
- Add item icons — `ItemRow.tscn` has room for a `TextureRect` next to the name label.

**Font note:** two fonts are already installed and working via `font_composite.tres`:
- **Anime Ace 2** (`animeace2_reg.ttf`) — used for all Latin / UI text
- **Aihara Hudemoji Kaisho** (`Aiharahudemojikaisho_free305.ttf`) — used as fallback for kanji and kana rendering

To render a specific Label in the Japanese font only (e.g. the big boss kanji), override `theme_override_fonts/font` to point directly to the `.ttf` rather than the composite.

### 2. Sound design

The game is completely silent. `AudioManager.gd` is a stub with `play_sfx(name)` and `play_music(name)` methods that do nothing. Wiring it up is intentionally straightforward:

- Add `.ogg` or `.wav` files to `res://assets/audio/sfx/` and `res://assets/audio/music/`
- Implement `AudioManager._load_sounds()` and stream lookups by name
- Call sites are already written throughout the codebase — grep for `AudioManager.play_sfx` and `AudioManager.play_music` to find them, then uncomment

Music direction: lo-fi traditional Japanese instruments (shakuhachi, koto, taiko). One track per zone, a boss-fight variant, a victory sting.

### 3. Content expansion

The data structure is ready. Adding content is pure JSON editing.

**Kanjis — Zones 2, 3, 4 need ~135 kanjis each:**

Each kanji entry in `kanji_data.json` needs:
```json
{
  "id": 46,
  "character": "心",
  "meanings": ["heart", "mind"],
  "kun_yomi": ["こころ"],
  "on_yomi": ["シン"],
  "stroke_count": 4,
  "first_stroke_hint": "Curved stroke on the left",
  "unlock_at_player_level": 26,
  "zone_id": 2
}
```

The `first_stroke_hint` is used in the parry overlay at attempt 3 (most faded). It's a plain English sentence. Currently only the first 10 kanjis have it — ideally all kanjis should.

**Items:** `items_data.json` supports `effects` arrays with multiple stats per item. New tiers and new set combinations are a few JSON lines each. Consider zone-specific drops in future (e.g. Zone 2 items drop in Zone 2 shops only).

**Boss variety:** `BossGenerator.gd` picks a name from a hardcoded array. Consider per-zone name pools, or add `boss_names` to `zones_data.json`.

### 4. Parry system improvement

The current drawing scorer is a proof-of-concept. It divides the canvas into a 4×4 grid and checks what percentage of cells contain ink — it doesn't understand what was drawn, only that something was drawn. The 40% threshold means any rough scribble that covers the canvas passes.

This is intentionally left simple because proper stroke recognition is a non-trivial computer vision problem. Here are the options, in increasing complexity:

- **Short-term** — raise `COVERAGE_THRESHOLD` from `0.40` to `0.60`, and add a stroke-count check (if `abs(drawn_strokes - expected_stroke_count) > 2`, fail). This makes the system harder without replacing it.
- **Medium-term** — implement the **$1 Unistroke Recognizer** (Wobbrock et al., 2007 — MIT licensed, public domain reference implementation). It normalizes stroke data and compares against templates. The kanji templates would need to be recorded once per character. This gives true shape matching.
- **Long-term** — integrate a proper stroke-order validator. This would require encoding the correct stroke sequence for each kanji (there are standard databases for this), then comparing the drawn sequence. This is the most educationally valuable version — stroke order is a real part of learning kanji — but also the most work.

The `KanjiDrawing.gd` system already stores strokes as `Array[Array[Vector2]]`, which is the right format for all three approaches.

### 5. Game feel & interaction depth

The game currently has no feedback beyond text label color changes. Each of the following is a small independent addition:

- **Tween animations** — smooth HP bar decrease (`create_tween().tween_property(bar, "value", target, 0.4)`), button scale pulse on correct answer, number popups showing damage dealt
- **Crit / dodge effects** — a `GPUParticles2D` burst on crit, a `modulate` flash on dodge
- **Boss attack telegraph** — a shake or color warning on the boss sprite in the 2–3 seconds before a parry triggers
- **Combo system** — track consecutive correct answers; a streak of 3+ multiplies damage by 1.5x, streak of 5+ by 2x. Resets on any wrong answer or timeout.
- **Status effects** — ice (slows timer), burn (DoT on player), stun (boss loses one hit point automatically). Triggerable by specific consumable items.
- **Animated boss defeat** — currently the boss just disappears. A brief animation or text sequence before the victory screen makes victories feel earned.
- **Background** - Add backgrounds for each zone and the different menus. Maybe draw a map for a better representation of the different zones in the world map menu.
- **Assets** - Add assets for the different bosses (the kanjis are currently placeholders), add assets for the different items/upgrades.
- **UI** - Add a proper UI and an inventory for the different items. 
- **Drops** - Possibily add item drops to bossfights on top of the ones available in the shop. 
- **Sounds** - Add sounds and music. 

### 6. Platform & distribution

The codebase is already structured for it. No changes needed to run on:
- **Android / iOS** — Current development target. NavBar is sized for thumbs. Main thing to audit is font rendering at small sizes.
- **Desktop** — Works fine on desktop, despite the vertical format not being adapted.
- **Web (HTML5)** — Godot exports directly. Main thing to test is touch input in `KanjiDrawing.gd` (already implemented via `InputEventScreenDrag`).

---

## Team

| Role | Name |
|---|---|
| Game Design & Development | Stella Rosier |
| Game Design & Development | Jules Cambon |
| Game Design & Development | Théo Baugey |
| Art & Visual Assets | ----------- |
| Japanese Content & Accuracy | ------------ |
| Sound Design | ----------- |

---

## License & Credits

**License:** MIT License

**Fonts:**
- *Anime Ace 2* by Blambot Fonts — [confirm license before distribution]
- *Aihara Hudemoji Kaisho Free* — freeware, non-commercial use

**Kanji data:** meanings and readings follow standard references (JMdict / KANJIDIC). If distributing commercially, review the JMdict license (CC BY-SA 4.0).

**Engine:** Built with [Godot Engine](https://godotengine.org) (MIT License).

---

*The core game is there. Add your ideas if you wish.*
