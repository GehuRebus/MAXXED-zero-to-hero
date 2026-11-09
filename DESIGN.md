# Game: MAXXED! College Zero to Hero!

## Pitch
Kimmy is a broke and fairly stupid college student. Guide her through 14 days of exams and labs by choosing how she spends her energy each day.

## Tech
- Godot 4.7.2, GDScript with static typing
- 2D, 16:9, Windows and Linux
- All tunable numbers live in one config resource (`GameConfig.tres`), never hard-coded in scripts

## Core loop
1. A day starts. Kimmy has 3 energy.
2. The player plays cards from a fixed set. Any card can be played any number of times while energy remains. Each card costs 1 energy.
3. The player ends the day (or runs out of energy).
4. Any events scheduled for that day resolve.
5. End-of-day checks run (gloom lockout, loss conditions).
6. The day counter increments. Repeat until day 14 is survived or the run is lost.

## MVP scope (must have)

### Stats
| Stat | Start | Min | Notes |
|---|---|---|---|
| Energy | 3 | 0 | Refills to 3 at the start of every day |
| Intellect | 20 *(placeholder)* | 0 | Clamped at 0. Ending a day at 0 intellect loses the run |
| Gloom | 20 *(placeholder)* | 0 | Ending a day at 100+ gloom loses the run |

- All stat changes are integers. Fractions from multipliers round down.
- Event checks compare against a stat. They do not spend it.

### Gloom lockout
- At the end of a day (after events), if gloom is **80 or more**, the next day starts **locked**.
- While locked, cards tagged `blocked_by_gloom` can't be played. In the MVP that's only Study.
- The lock is re-checked at the end of every day, so it lifts once gloom drops below 80.
- Example: Kimmy ends day 10 at 90 gloom. She could still play Study during day 10, but not on day 11.

### Cards
All cost 1 energy, and all effects are permanent.

| Card | Intellect | Gloom | Tags |
|---|---|---|---|
| Study | +10 (× streak multiplier) | +15 | `blocked_by_gloom` |
| Game | — | −6 | Safe pick: no drawback |
| Party | −7 | −11 | — |

**Study streak:** each Study played immediately after another Study in the same day gets a bigger intellect bonus. Proposed: 1st ×1.0, 2nd ×1.1, 3rd ×1.2. Playing any other card or ending the day resets the streak. Gloom gain is not multiplied.

### Events
**Stat checks** (fail = run over):
| Event | Requirement | Side effect |
|---|---|---|
| Exam | Intellect ≥ 50 *(placeholder)* | — |
| Lab | Intellect ≥ 35 *(placeholder)* | +10 gloom *(placeholder)*, applied after the check |

**Random events** (no check, just stat changes):
| Event | Effect |
|---|---|
| Study Group | +8 intellect, +10 gloom *(placeholder)* |
| Bad News From Home | +12 gloom *(placeholder)* |

**Scheduling:**
- The schedule is generated once, at the start of each run.
- Exams and labs are spaced randomly but requirements are fixed and known, so the player can plan.
- A day can have more than one event.
- Requirements don't grow during the 14-day MVP.

**Resolution order on a day with events:**
1. All stat checks are made against the stats Kimmy ended the day with. Any failure ends the run.
2. Then all side effects and random-event effects apply.
3. Then the end-of-day checks (gloom lockout, 0 intellect, 100 gloom) run.

### Win / lose
- **Win:** finish day 14 with every event passed and no loss condition triggered.
- **Lose (any of):** fail any event check · end a day at 0 intellect · end a day at 100+ gloom. A loss from stats shows as a game-over at the start of the next day.

### Presentation
- Placeholder art only: solid-colored shapes (`ColorRect`/`Panel`) labeled with what they represent.
- Always visible: day counter, energy, intellect, gloom (with the 80 lockout line marked), current study streak.
- Locked cards are visibly greyed out, with the reason shown.
- An event resolution popup shows each event, the requirement vs Kimmy's stat, and pass/fail.

## Not in MVP
- Cards beyond Study, Game, Party
- Temporary (time-limited) effects
- Events beyond Exam, Lab, Study Group, Bad News From Home
- Requirement growth over time, and new events joining the pool later
- Stats beyond intellect and gloom
- Real art, audio, menus beyond start / game over / win / restart
- Saving mid-run

## Controls
- Mouse: click a card to play it; click "End Day" to end the day.

## Open questions
**Decided for milestone 4 (events)** (all numbers in `GameConfig.tres`):
- Schedule visibility: the player sees **today plus the next 3 days** (`schedule_lookahead_days`). The intellect bar also marks the next visible check's requirement.
- Random events are **rolled at run start but hidden**; they show up as a "Surprise!" in the end-of-day popup.
- Per run: **2 exams, 3 labs** (`count_per_run` on each event) and **3 random events** (`random_event_count`, each drawn evenly from Study Group / Bad News).
- Placement: **day 14 is always an exam** (`final_day_event`, counts toward the 2); **no checks before day 3** (`first_check_day`); at most **one check per day**. Random events can land on any day, including check days.

**Can wait until tuning:**
- Starting intellect and gloom values.
- Exam and lab requirements. With the current cards, net intellect gain while holding gloom steady is small (e.g. Study + Game + Game ≈ +10 intellect, +3 gloom per day), so requirements need to be set against that.
- Should the Study streak carry across days instead of resetting each day?

**Post-MVP design:**
- Should the player have more stats to care about?
- Should stats interact more with events?

## Done when
A stranger can play a full 14-day run, understand why they won or lost, and win at least once with no outside help.

---

## Build plan
Every milestone ends with something you can run (F5) or test headless.

1. **Skeleton & data:** project setup, `GameConfig` resource, `CardData` / `EventData` resources for the 3 cards and 4 events, and a `RunState` script holding stats and rules. Game logic is kept separate from UI so it can be unit-tested headless (GUT or gdUnit4).
2. **Playable day:** stat display, three card buttons, energy, End Day button. Cards change stats; days advance; no events yet.
3. **Rules:** Study streak multiplier, gloom lockout (greyed-out Study), 0-intellect and 100-gloom losses, game-over screen with restart.
4. **Events:** schedule generation, exam/lab checks, random events, resolution popup, upcoming-event display. Needs the first open questions answered.
5. **Full run:** 14-day win screen, restart flow, a debug option to reuse a fixed random seed for reproducible runs.
6. **Tuning & playtest:** adjust `GameConfig` numbers until a run is winnable but tense, then hand it to a stranger.
