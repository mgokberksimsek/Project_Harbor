# Project Harbor Development Guide

This file applies to the entire repository. It records how Project Harbor
should be designed and changed; it is not a reason to rewrite working code.

## Product direction

- The core fantasy is **growing a shipping company**, not manually driving a
  ship.
- Prefer a small feature that creates clear player value over a broad system
  that may be useful later.
- Keep the mobile loop short and legible: select a ship, choose a marked port
  and mission, then let the ship operate automatically.
- New mechanics should strengthen fleet growth, port-network growth or useful
  company decisions. Question features that do none of these.

## Default decision rule

1. Choose the simplest understandable solution.
2. Fit it into the existing architecture and code style.
3. Make it scalable only where the current feature needs it.
4. Add an abstraction only when a concrete present-day problem requires it.

Do not add systems, save fields, managers, resources or extension points only
because they might be useful later. Do not force every feature into a
`Manager + UI + Resource + Event + System` package.

## Before changing code

- Read the relevant scenes, scripts and resources completely enough to
  understand the current behavior.
- Check signal connections, callers, dependencies, save/load behavior and
  existing tests.
- Preserve unrelated user changes and working gameplay.
- Make the minimum coherent change in the fewest appropriate files.
- Do not perform speculative cleanup alongside a feature.

If a working system truly needs replacement, explain before implementation:

1. why replacement is necessary;
2. which files and behaviors are affected;
3. which concrete problem in the old system it solves.

## Architecture

- Prefer giving a feature to the existing system that already owns the data or
  behavior.
- Do not create another manager while an existing manager has a clear home for
  the behavior.
- Existing managers and signals are not to be consolidated or rewritten merely
  to reduce their count.
- Use signals to announce meaningful facts that other parts of the game need to
  observe. Do not create a global event for every command or local UI action.
- Keep commands explicit and readable. UI mediation should follow the existing
  local flow instead of introducing a new layer by default.
- Split an oversized function into logical helpers, but do not create a class
  for every small operation.

## Data, time and saves

- Use `.tres` resources for designer-authored ports, ships, cargo and routes.
- Keep runtime save state separate from authored resource data. Never save
  `Node` or `Resource` references.
- User-facing saves should remain versioned, migration-friendly JSON or an
  equivalently safe format.
- Time-based gameplay should retain enough state to reconstruct progress after
  closing the app, normally `start_time`, `duration` and runtime `state`.
- Values designers are likely to tune belong in an existing resource or a
  clearly named constant/export, not scattered magic numbers.

## Progression and economy

- Cash is spendable; Company Value measures owned assets; Company Level is the
  permanent progression tier. Do not blur their roles.
- Company Level may unlock ships, regions, cargo, capacity and later features,
  but it must not become the only condition for everything.
- Prefer at most `Company Level + Cash + one thematic condition` for special
  content. Most content should need fewer conditions.
- Do not reward one activity heavily across every progression currency.
- Repeating the same short route forever must not become the dominant strategy,
  but test the base economy before adding demand, contracts or market systems.
- Add route-variety mechanics one at a time and measure their effect before
  adding another.

## Mobile UX and game feel

- Keep touch targets generous and avoid text-heavy or oversized panels.
- Use screen space efficiently and keep critical actions within a few taps.
- Do not send players through several menus for a routine mission action.
- Test layouts on the connected Android device when a change is visual or
  touch-related.
- Important actions need clear, restrained feedback: selection, departure,
  arrival, loading, delivery, earnings, Company Value growth, level-up and
  unlocks. Prefer one strong cue over several noisy effects.
- Technical correctness alone is not completion when an interaction looks or
  feels abrupt.

## Feature workflow

For a requested feature:

1. Evaluate its player purpose and its economy/progression consequences.
2. Identify the existing owner of the behavior; avoid a new abstraction by
   default.
3. State the files and existing behavior that will change when the impact is
   non-trivial.
4. Implement the smallest playable version.
5. Validate Godot 4.7.1 syntax, runtime errors, null safety, signal wiring,
   save/load compatibility, existing gameplay and relevant mobile behavior.
6. Briefly report what changed and what was tested.

Ask before implementation when gameplay intent has materially different valid
options, the current behavior cannot be established, or the data model must
change. Do not interrupt progress for small, reversible implementation details.

## Documentation and Git

- Update `docs/GDD.md` only for durable player-facing design decisions.
- Update architecture documentation only when the actual architecture changes.
- Do not turn implementation details or temporary test values into GDD rules.
- Group changes into meaningful commits. Remind the user when a coherent change
  is ready for commit/push, but do not commit or push without their request.

