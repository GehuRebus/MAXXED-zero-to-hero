# Balance notes (milestone 6)

## Target
- A thoughtful player wins **~60–75%** of runs; a careless one mostly loses.
- Tune DESIGN.md's *placeholder* numbers first; touch cards or the streak only if needed.

## Method
`tools/sim/` plays seeded runs through the real `RunState` rules:

```sh
godot --headless -s tools/sim/simulate.gd -- --runs=2000
godot --headless -s tools/sim/simulate.gd -- --strategy=good --set=event.exam.check_min=90 --set=start_gloom=30
```

| Strategy | What it does |
|---|---|
| `good` | Each day, tries every card sequence and keeps the best by a player-like score: never fail a visible check, keep a buffer under the gloom limit, avoid tomorrow's lockout, stay on track for the checks it can see, and otherwise prefer intellect. **It sees only what a human sees:** stats and the 4-day schedule strip, never the hidden random events. |
| `pattern` | Study, Game, Game every day: DESIGN.md's "≈ +10 intellect, +3 gloom" line. A player who doesn't think. |
| `always_study` | Study whenever allowed. The careless grinder. |
| `random` | Random legal cards. |

All strategies play the same seeds, so they face the same schedules. Each run of the simulator also reports the average loss day, final stats, lockout days, and "close calls" (checks passed by ≤5, days ending at 85+ gloom).

## Results
Original numbers (2000-run reports from seeds 1–2000):

| | good | pattern | always_study | random |
|---|---|---|---|---|
| **Before** (DESIGN.md placeholders) | 97.6% | 89.6% | 0% | 18% |
| **After** (shipped) | **71.9%** | 49.5% | 0% | 0% |

Checked on fresh seeds 50001–51000: good 70.1%, pattern 46.0%.

The skill gap (good vs pattern) went from 8 to 22 points, and the average loss moved from day ~4.6 (early-exam luck) to day ~6.6.

### What changed
| Value | Before | After | Why |
|---|---|---|---|
| Exam requirement | 50 | **100** | At 50 the good player ends runs at ~150 intellect: checks were never in doubt. |
| Lab requirement | 35 | **65** | Keeps labs a real check under the new exam bar. |
| Lab gloom | +10 | **+15** | Labs now cost something even when passed. |
| Start gloom | 20 | **25** | The early Study rush gets closer to the lockout. |
| First check day | 3 | **5** | See below. Still honours "no checks on days 1–2". |
| Intellect bar scale | 100 | 150 | Presentation only: the exam marker isn't pinned to the bar's end. |

Card values and the Study streak are **unchanged**; the placeholders were enough.

### Why the first check moved to day 5
With a demanding exam requirement, an exam on day 3–4 is out of reach for *any* strategy (from 20 intellect, gloom caps how much you can Study in 2–3 days). At day 3, about 60% of the good player's losses were these unwinnable early exams. That's bad luck, not tension. Day 5 gives enough runway to make the early game a planning problem instead.

Even so, a day-5 exam needing 100 is still very tight. About 8% of runs are lost to an exam on exactly day 5, and some of those are probably unwinnable. If playtesters call that unfair, try `first_check_day = 6` or `exam check_min = 95`.

## Structural finding: the late game can't be tense with the MVP rules
Intellect is permanent and requirements are fixed (DESIGN.md: "Requirements don't grow during the 14-day MVP"). Once Kimmy clears the exam bar, every later check is already passed, and Game ×3 (−18 gloom/day, no drawback) always fixes gloom. So:
- Losses cluster in **days 5–9**, the race to the first exam.
- Days ~10–14 are mostly a victory lap. Late losses are rare gloom accidents (a lab and Bad News landing together).

No choice of numbers fixes this; it needs a rule change. These are post-MVP options to raise with design, in rough order of fit:
1. **Requirement growth** (already listed as "not in MVP"): later exams ask for more.
2. **A distinct final exam** with its own higher requirement on day 14.
3. **Gloom drift**: a small passive gloom gain each day, so Game isn't free maintenance.
4. **Intellect decay**: unused knowledge fades a little each day.

## Playtest checklist (the human half of milestone 6)
DESIGN.md's bar: *"A stranger can play a full 14-day run, understand why they won or lost, and win at least once with no outside help."*

1. Give the tester an export or `godot --path .`, and no explanation beyond "Click cards, then End Day".
2. Watch silently. Note where they hesitate or misread the screen (the streak, the lockout line, the schedule strip, the popup).
3. After each run, ask "Why did you win or lose?" and compare the answer with the game-over or win screen.
4. Write down the **seed** from the end screen for any surprising run. It replays exactly with `-- --seed=N`.
5. Record wins/losses. If they can't win within ~3–4 runs, consider `exam check_min = 95` or `first_check_day = 6`.
6. Try value changes live via **Settings → Debug: game config** (debug builds), then copy the keepers into `data/GameConfig.tres`.

If shipped values change, update `tests/unit/test_data.gd`. The balance guard in `tests/unit/test_balance_sim.gd` fails if the good player leaves 60–80%.
