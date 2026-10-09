# Carrot Market – rules for every session

Roblox game built entirely from this repo (Rojo + Luau). The full design doc ("Carrot Market – Designplan v2") is the spec; this file is the short version. Build phase by phase and stop at each gate so Philip can playtest.

## Project facts
- Repo: `ds2877/cm` only. Never touch other repos.
- Universe `10769879996`, start place `87874194731556`.
- Push to `main` = publish (GitHub Actions, secret `CM_PUBLISHING_KEY`). Other branches run checks only.
- In-game text is English (Roblox auto-translation on). STATUS.md is written in Swedish for Philip.
- Philip tests mostly on iPhone: mobile first, big buttons, nothing needs hover or keyboard.

## Build rules
1. Never write the publishing key anywhere; read it only from the Actions secret.
2. Everything is code. World, farms, carrots and UI are built at runtime. Nothing manual in Studio.
3. Uploaded assets (sounds, icons, meshes) live in `src/shared/Config/Assets.luau`. Empty ID = the game still works (primitives / silence). List missing assets in STATUS.md.
4. Server decides everything that touches the economy. Clients send intents only ("act on plot 3"), never values. Validate and rate-limit every remote.
5. Every number (chances, prices, times, multipliers) lives in `src/shared/Config/*`. Never hardcode balance in logic.
6. Monetization follows the design doc §8/§11: no random rewards for Robux, known contents for everything bought with Robux, boosts count play time, no fake countdowns, no fake glow/near-miss.
7. `--!strict` in every file. StyLua + Selene + Lune tests must pass (CI runs them before publishing).
8. After every ticket: update STATUS.md (done / how to test / missing). After every phase: publish and ask Philip to test the gate.
9. When unclear: pick the simplest thing that keeps the core loop fun, do it, and note the decision in STATUS.md.

## Design pillars (short)
- Core promise: *the next carrot might be insane*. Cut anything that doesn't feed that.
- Never more than 3–4 s without something about to finish (staggered plot timers).
- Reveal in three honest steps while growing: shimmer (Rare+ or mutation) → sparks (Epic+) → light pillar + sound (Legendary+, visible to others). Glow only when something is really there.
- Harvest moment scales with value. Always show the next goal (goal bar). Pity guarantees Legendary.
- Value = base × size × mutation × market × (1 + valueUpg) × prestige × min(boosts, 6). Shared in `src/shared/Value.luau`.
- Market gives a decision, never a loss: prices never go below base. Global schedule from `os.time`.
- UI: mobile first, bright child-friendly colors, chunky simulator style (Luckiest Guy, thick outlines, tiles with badges). Better carrots get more particles (Config/Rarity aura).
- HUD layout: the screen center belongs to the farm. Currencies = dark-glass pills top-left; menu = 2x2 buttons on the left edge; SELL right edge above jump; goal bar in the top bar. Author for a 520 pt tall screen; scale only via `UI.screenScale` (never a private copy).
- World art direction ("sunny valley farmers' market"): green = land, warm dirt = paths, orange/cream = the market (the hero landmark), dark soil = plots so carrots pop. Each farm has an identity color (barn + sign). Signs are physical boards (SurfaceGui), not floating billboards; floating UI only for small, glanceable info (boom timer). Moderate saturation; no neon except reveal effects.
- Economy: next purchase 30–90 s away early, 2–3 min after 30 min, 3–5 min after an hour. Simulate before locking curves.

## Layout
- `src/shared` → ReplicatedStorage.Shared (Config, pure logic: Format, Value, Roller, Progression, EventSchedule; CarrotInfo, Remotes, Types)
- `src/server` → ServerScriptService.Server (Services: WorldBuilder, Data, Roll, Farm, Economy, Upgrade, Seeds, Dex, Offline, Buffs, Social, Announce, Leaderboards, Perks, Product, Telemetry)
- `src/client` → StarterPlayerScripts.Client (Controllers: HUD, Shop, Seeds, Dex, Offline, Plot, RevealFX, HarvestFX, Farms, MarketBoard, Store; Util: UI, Panel, Sound, CarrotModel, CarrotIcon)
- `tools/simulate.luau` economy simulation → `tools/simulation-report.md`. Re-run after any balance change.
- `tests/` Lune specs (`lune run tests`). Pure modules must not use Roblox APIs so Lune can test them.
- Plot state is replicated via attributes on plot parts; clients render all plots from them.

## Admin
- Admin dashboard (⚙️ corner button) for admins only: `Config/Admin.luau` + experience owner (+ everyone in Studio). Every action is re-validated in `Services/Admin.luau`.
- Event overrides live in workspace attributes (`AdminBoom*`, `AdminEventsOff`, `AdminDailyRarity`); read market state via `Shared/Market.luau` (`Market.state()`), never `EventSchedule.at` directly.

## Local checks
```
./tools/install-tools.sh        # or: rokit install
stylua --check src && selene src && lune run tests && rojo build default.project.json -o cm.rbxl
```
