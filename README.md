# MAXXED! College Zero to Hero!

A 14-day card-driven survival game about Kimmy, a broke and fairly stupid college student. See [DESIGN.md](DESIGN.md).

Built with **Godot 4.7.2** (GDScript, static typing).

## Layout
- `data/GameConfig.tres` — every tunable number, plus the card and event lists
- `data/cards/`, `data/events/` — `CardData` / `EventData` resources
- `scripts/core/run_state.gd` — all game rules, no UI (unit-tested)
- `scripts/core/schedule.gd` — per-run event schedule, generated from a seed
- `scripts/core/game_session.gd` — session copy of GameConfig that the debug menu edits
- `scripts/data/` — resource class definitions
- `scripts/ui/` — day screen (`main_screen.gd`), card buttons, stat bars; reads RunState, holds no rules
- `tests/unit/` — GUT tests (rule tests use `tests/test_fixtures.gd`, pinned to DESIGN.md's original numbers, so retuning doesn't break them)
- `tools/sim/` — headless balance simulator
- `docs/BALANCE.md` — tuning results and playtest checklist
- `addons/gut/` — vendored [GUT](https://github.com/bitwes/Gut) 9.7.1

## Run the tests (headless)
```sh
godot --headless --import                         # first time only
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```
Or open the GUT panel in the editor.

## Menus
The game opens on a start menu (Play / Settings / Quit). The game screen has a **Menu** button, and the game-over and win screens have **Main menu**.

## Debug: tweak GameConfig in-game
In debug builds (editor runs and debug exports), **Settings → Debug: game config** lets you edit every tuning number: GameConfig values, each card's cost and effects, and each event's requirement, effects and count per run.
- Edits apply to the **next run** and last until the game closes. `data/GameConfig.tres` is never modified. Copy any values you want to keep into it by hand.
- **Reset to defaults** reloads the shipped values.
- Fields are generated from the resources' exported properties, so new tuning values appear automatically.

## Debug: replay a run with a fixed seed
Every run's schedule (exam/lab days and surprise events) comes from one seed, shown on the game-over and win screens.
- Command line: `godot --path . -- --seed=12345`
- Or set `debug_seed` in `data/GameConfig.tres` (Debug group), or in the in-game debug menu. `-1` = random every run.

With a fixed seed, Restart / Play again replays the same schedule.

## Balance simulator
Plays thousands of seeded runs headless with several strategies and reports win rates:
```sh
godot --headless -s tools/sim/simulate.gd -- --runs=2000
godot --headless -s tools/sim/simulate.gd -- --strategy=good --set=event.exam.check_min=90
```
`--set` tries values without editing files. Results and tuning rationale: [docs/BALANCE.md](docs/BALANCE.md).

## Status
- [x] Milestone 1 — skeleton, data resources, RunState rules + tests
- [x] Milestone 2 — playable day (stat display, cards, energy, End Day)
- [x] Milestone 3 — rules UI (streak, lockout, game over + restart)
- [x] Milestone 4 — events & schedule (lookahead strip, hidden surprises, results popup)
- [x] Milestone 5 — full run (win screen, play again, debug seed)
- [x] Milestone 6a — tuning with the balance simulator (see [docs/BALANCE.md](docs/BALANCE.md))
- [ ] Milestone 6b — hand it to a stranger (playtest checklist in docs/BALANCE.md)
