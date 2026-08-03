# Harbor Tycoon — Architecture

Godot 4, 2D, mobile-first (landscape), single player. This document is the
source of truth for how the codebase is organized and *why*. Read it before
adding a new system.

## Guiding rules

1. **No hardcoded entities.** Ports, cargo types, and ship models are data
   (`Resource` assets), not code. Adding one is a new `.tres` file, never a
   new branch/enum case/if-chain.
2. **Managers own state, EventBus carries notifications.** A manager never
   calls another manager's method directly to *react* to something that
   happened — it emits on `EventBus` and the other manager subscribes. Direct
   calls are fine for *queries* (e.g. UI asking `PortManager.get_unlocked_ports()`).
3. **Cross-references are IDs, not Nodes/Resources.** A `Mission` stores
   `pickup_port_id: StringName`, never a `Port` node. This is what keeps
   save/load, and the whole system, decoupled from scene layout.
4. **Time-based, not frame-based.** Mission progress is computed from
   Unix timestamps (`leg_start_unix` + `leg_duration_sec`), not accumulated
   per-frame. This is required for idle income / offline progress to work
   without a separate "catch-up" system bolted on later.
5. **Resources for assets, JSON for save games.** `ResourceSaver`/`ResourceLoader`
   are for editor-authored `.tres` assets only. Save games are plain JSON —
   Godot's own docs flag loading arbitrary `.tres` save files as a security
   risk (embedded scripts can execute on load).

## Layers

```
Data resources (.tres)  →  Autoload managers  →  EventBus  →  Scenes & UI
  PortData                   PortManager
  CargoTypeData               FleetManager
  ShipData                    MissionManager
							   EconomyManager
							   CompanyManager
							   GameManager
							   SaveManager
```

## Autoloads and their single responsibility

| Autoload | Owns | Does NOT own |
|---|---|---|
| `EventBus` | All cross-system signals | Any state |
| `GameManager` | Currency, game-flow/session state | Ports, ships, missions |
| `PortManager` | Port registry, unlock/level state, id lookup | Port visuals (Port scene) |
| `FleetManager` | Ship registry (player + future AI), mission assignment | Mission generation |
| `MissionManager` | Mission generation & lifecycle | Reward math, currency |
| `EconomyManager` | Stateless reward/cost formulas | Any persisted state |
| `CompanyManager` | Derived Company Value, peak value, permanent Company Level | Cash, ships, ports |
| `SaveManager` | Serialize/restore all manager state, versioning | Game logic |

**Autoload registration order** (Project Settings > Autoload) — top to
bottom, since later autoloads may reference earlier ones on `_ready()`:

1. `EventBus`
2. `PortManager`
3. `FleetManager`
4. `MissionManager`
5. `EconomyManager`
6. `CompanyManager`
7. `GameManager`
8. `SaveManager`

## Folder structure

```
res://
  scenes/
	world/World.tscn
	ship/Ship.tscn
	port/Port.tscn
	ui/HUD.tscn, MissionPanel.tscn, PortUnlockPopup.tscn
  scripts/
	autoload/          # one script per autoload above
	data/               # port_data.gd, cargo_type_data.gd, ship_data.gd
	runtime/            # mission.gd, and future runtime-only data classes
	port/               # port.gd (Port scene behavior)
	ship/               # ship.gd + ship state machine
	ui/                 # hud.gd, mission_panel.gd, ...
  resources/
	ports/              # port_izmir.tres, port_rotterdam.tres, ...
	cargo_types/        # cargo_containers.tres, cargo_oil.tres, ...
	ships/              # ship_default.tres
  docs/
	ARCHITECTURE.md      # this file
```

## Why a `PortManager` *and* a `FleetManager` (not just `GameManager`)

The original draft had `GameManager` own "money, unlocked ports, player
progress, statistics." That collapses into a God Object the moment ports
gain levels, ships multiply, and captains/weather get added — every new
feature edits the same file. Splitting by concern means:

- Adding port upgrades touches `PortManager` and `PortData` only.
- Adding a second player ship touches `FleetManager` only.
- Adding AI ships is "more entries in `FleetManager`'s registry," not a new
  parallel system.

## Why `Mission` is a `RefCounted`, not a `Resource`

`Resource` is for assets you author in the editor and load from disk.
`Mission` is generated at runtime, thousands of times over a play session,
and needs `to_dict()`/`from_dict()` for JSON save/load — a plain
`RefCounted` with explicit (de)serialization is lighter and avoids Resource's
asset-oriented assumptions (unique paths, `ResourceSaver` security caveats).

## Roadmap

- [x] Phase 1 — Core data layer: `EventBus`, `PortData`, `CargoTypeData`,
      `ShipData`, `Mission`
- [x] Phase 2 — `PortManager` + `Port` scene (data-driven, no hardcoded ports)
- [x] Phase 3 — `FleetManager` + `Ship` scene with an explicit state machine
- [x] Phase 4 — `MissionManager` (generation, assignment, timestamp-based
      completion)
- [x] Phase 5 — `EconomyManager` (distance/cargo/level reward formulas)
- [ ] Phase 6 — `GameManager` (currency, stats, game-flow; currency slice exists)
- [ ] Phase 7 — `SaveManager` (JSON, versioned)
- [ ] Phase 8 — UI (HUD, mission panel, port unlock popup)
- [ ] Phase 9 — Mobile polish: touch input, camera, safe-area, Android export

## Deferred future systems and where they'll slot in

| System | Slots into | Notes |
|---|---|---|
| Multiple player ships | `FleetManager` | Already a registry, not a singleton |
| AI ships | `FleetManager` | Same registry, a `is_player_controlled` flag |
| Port upgrades | `PortData` + `PortManager` | Cost/multiplier arrays already present |
| Cargo types | `CargoTypeData` | New `.tres`, zero code |
| Weather | New `WeatherManager` autoload | Subscribes to/emits on `EventBus` only |
| Fuel | `ShipData` + `Ship` state machine | Fields already reserved on `ShipData` |
| Captains | New `CaptainData` resource + slot on `Ship` | Multiplier feeding `EconomyManager` |
| Idle income | `Mission` timestamps + `SaveManager` | Compute elapsed time on load, fast-forward |
| Save/load | `SaveManager` | JSON, not `.tres` |
| Google Play release | Export presets, Android permissions | Phase 9 |
