# MAXXED! College Zero to Hero!

A 14-day card-driven survival game about Kimmy, a broke and fairly stupid college student. See [DESIGN.md](DESIGN.md).

Built with **Godot 4.7.2** (GDScript, static typing).

## Layout
- `data/GameConfig.tres` — every tunable number, plus the card and event lists
- `data/cards/`, `data/events/` — `CardData` / `EventData` resources
- `scripts/core/run_state.gd` — all game rules, no UI (unit-tested)
- `scripts/data/` — resource class definitions
- `scripts/ui/` — day screen (`main_screen.gd`), card buttons, stat bars; reads RunState, holds no rules
- `tests/unit/` — GUT tests
- `addons/gut/` — vendored [GUT](https://github.com/bitwes/Gut) 9.7.1

## Run the tests (headless)
```sh
godot --headless --import                         # first time only
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```
Or open the GUT panel in the editor.

## Status
- [x] Milestone 1 — skeleton, data resources, RunState rules + tests
- [x] Milestone 2 — playable day (stat display, cards, energy, End Day)
- [ ] Milestone 3 — rules UI (streak, lockout, game over)
- [ ] Milestone 4 — events & schedule
- [ ] Milestone 5 — full run
- [ ] Milestone 6 — tuning & playtest
