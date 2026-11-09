# Design decisions: MVP and beyond

Every significant choice made while building the MVP of *MAXXED! College Zero to Hero!*: what was decided, why, what it costs, and how it should evolve. [DESIGN.md](../DESIGN.md) is the spec; this document records how the spec was interpreted and implemented. [BALANCE.md](BALANCE.md) has the tuning data.

Each entry uses the same four parts:
- **Decision:** what the MVP does.
- **Why:** the reason, and who decided (the spec, the user, or an implementation call).
- **Trade-off:** what it costs or leaves out.
- **Next:** how to improve it in further development.

Contents:
1. [Architecture](#1-architecture)
2. [Data and configuration](#2-data-and-configuration)
3. [Core rules](#3-core-rules)
4. [Events and schedule](#4-events-and-schedule)
5. [Randomness and seeds](#5-randomness-and-seeds)
6. [Presentation and UI](#6-presentation-and-ui)
7. [Menus and debug tools](#7-menus-and-debug-tools)
8. [Testing](#8-testing)
9. [Balance and tuning](#9-balance-and-tuning)
10. [Known gaps](#10-known-gaps)
11. [Roadmap](#11-roadmap)

---

## 1. Architecture

### 1.1 Game logic is separate from the UI
- **Decision:** All rules live in `RunState` (`scripts/core/run_state.gd`), a `RefCounted` with no Node or UI dependencies. UI scripts only read its fields, call `play_card()` / `end_day()`, and redraw on the `changed` signal.
- **Why:** Required by DESIGN.md milestone 1 ("Game logic is kept separate from UI so it can be unit-tested headless"). It also made the balance simulator possible: it drives the exact same `RunState` the game uses.
- **Trade-off:** A little more wiring, because the UI copies state into labels on every `changed`. The UI rebuilds everything on each change instead of updating only what changed; that's fine at this size.
- **Next:**
  - Emit finer-grained signals (`stat_changed(stat, old, new)`, `card_played`, `day_ended(result)`) so the UI can animate individual changes.
  - Introduce a command layer (`PlayCard`, `EndDay`) so a run is a list of commands. That gives undo, replays of real player runs, and save-anywhere for free.

### 1.2 Scenes for layout, code for repeated content
- **Decision:** Static layout (main screen, popups, menus) is in `.tscn` files with `%UniqueName` references. Repeated or data-driven content (card buttons, energy squares, schedule cells, debug fields) is built in code.
- **Why:** Layout stays editable in the Godot editor, while anything whose count depends on data (3 cards today, maybe 8 later) follows the data automatically.
- **Trade-off:** Code-built nodes don't appear in the editor's scene preview.
- **Next:** Turn `CardButton` and schedule cells into small `.tscn` scenes that code instances, so art and layout can be done in the editor once real art arrives.

### 1.3 Simple scene switching
- **Decision:** Start menu ↔ game screen use `get_tree().change_scene_to_file()`. Popups (results, game over / win) are overlay Controls inside the game scene.
- **Why:** The simplest thing that works for three screens.
- **Trade-off:** No transitions, and nothing survives a scene change except the static `GameSession`.
- **Next:** A small `SceneRouter` autoload with fade transitions and a place to keep cross-scene state (settings, the current run if mid-run saving is added).

### 1.4 Typed Dictionary results
- **Decision:** `end_day()` returns a `Dictionary` (`day, events, checks, effects, lost, won, loss_reason`).
- **Why:** Fast to build while the result's shape was still being discovered across milestones 1–4.
- **Trade-off:** No static typing on its fields, so typos surface at runtime and editor autocompletion doesn't help.
- **Next:** Replace it with a `DayResult` class (`RefCounted`, typed fields, `CheckResult` / `EffectResult` entries). This is a mechanical refactor now that the shape is stable.

---

## 2. Data and configuration

### 2.1 Every tunable number in data
- **Decision:** All gameplay numbers live in `data/GameConfig.tres`, plus the card (`data/cards/*.tres`) and event (`data/events/*.tres`) resources it references. Script defaults are deliberately neutral (`0` / empty / `-1`), so a missing value shows up as obviously wrong instead of quietly using a hidden number from code.
- **Why:** Required by DESIGN.md ("never hard-coded in scripts"). The neutral defaults were an implementation call after Godot omitted default-valued fields from the saved `.tres`, which would have left real numbers living in scripts.
- **Trade-off:** Godot still omits fields whose value equals the neutral default (for example `intellect_loss_threshold = 0` isn't written in the file). Placeholder colors and the intellect bar scale also live in data, which mixes presentation with balance.
- **Next:**
  - Split presentation values (colors, bar scale) into a separate `Theme`/`UiConfig` resource.
  - Add a validation pass at load time (num_days ≥ 1, thresholds ordered, checks fit in the schedule) that reports problems clearly instead of failing deep in a run.

### 2.2 Cards and events as fixed-field resources
- **Decision:** `CardData` has `energy_cost`, `intellect_delta`, `gloom_delta`, `uses_study_streak` and `tags`. `EventData` has a `kind` (STAT_CHECK or RANDOM), `check_stat`, `check_min`, `count_per_run` and stat deltas.
- **Why:** That covers exactly the MVP's 3 cards and 4 events with the least machinery. Behavior flags like `uses_study_streak` and the `blocked_by_gloom` tag keep special cases data-driven.
- **Trade-off:** Every new kind of effect (temporary buffs, drawing cards, changing tomorrow's energy) needs a new field and new code in `RunState`. Two hard-coded stats limit "more stats" ideas.
- **Next:** Move to a composable **effect system**: a card or event holds `Array[Effect]`, where `Effect` is a resource subclass (`ModifyStat`, `ModifyStatNextDay`, `GrantEnergy`, `AddTemporaryModifier`, …) with an `apply(run)` method. Store stats in a `Dictionary[StringName, int]` with a `StatDef` resource per stat (min, max, loss rule, display). This unlocks the post-MVP items "more cards", "temporary effects" and "more stats" without touching core code.

### 2.3 Tags for rule hooks
- **Decision:** Cards carry `tags: Array[StringName]`. The only tag the MVP uses is `blocked_by_gloom`.
- **Why:** The spec defines lockout in terms of a tag, so adding another blocked card is a data change.
- **Trade-off:** Tag names are plain strings; a typo silently does nothing.
- **Next:** Keep tags as constants in one place (as `CardData.TAG_BLOCKED_BY_GLOOM` already is) and have the validation pass warn about unknown tags.

---

## 3. Core rules

### 3.1 Integer stats, clamped at 0
- **Decision:** Intellect and gloom are `int`s, never below 0. Gloom has no upper clamp; reaching 100+ at the end of a day loses the run.
- **Why:** From the spec ("All stat changes are integers", "Min 0").
- **Next:** With the stat definitions from 2.2, min/max/loss rules become per-stat data.

### 3.2 Study streak as whole percentages
- **Decision:** `study_streak_percent = [100, 110, 120]`, applied as `(base * percent) / 100` with integer division. A streak longer than the list keeps using the last value (×1.2). Any non-streak card, or ending the day, resets it.
- **Why:** The spec proposes ×1.0/×1.1/×1.2 and "fractions round down". Whole percentages make rounding exact; floats can turn 10 × 1.1 into 10.999… The 4th-and-later rule was an implementation call, since the spec lists only three steps.
- **Trade-off:** Multipliers are limited to whole-percent steps (fine for design use).
- **Next:** The spec's open question "should the streak carry across days?" is still open, because tuning reached its target without it. Treat it as a design lever for late-game tension (see 9.3). A generalized modifier pipeline (2.2) would also let other cards have streaks or combos.

### 3.3 End-of-day resolution order
- **Decision:** `end_day()` runs these steps in order:
  1. Every stat check is compared with the stats Kimmy ended the day with. Any failure means a loss.
  2. Only if no check failed: all side effects and random-event effects apply.
  3. The lockout is set (`locked = gloom ≥ 80`), then the 0-intellect and 100-gloom losses are checked.
  4. The streak resets, then the day advances and energy refills, or the run is won after the last day.
- **Why:** This is the spec's resolution order. Skipping effects after a failed check is an implementation call; the run is already over, so applying them would only muddy the final stats.
- **Trade-off:** Checks never see same-day boosts (a Study Group can't rescue that day's exam). That's intended by the spec, and tested.
- **Next:** Keep the order explicit as named steps when the effect system arrives. New effect types (for example "prevent the next failure") will need defined places in this order.

### 3.4 Gloom lockout
- **Decision:** A `locked` flag is set at the end of each day from that day's final gloom and holds for the whole next day. Cards tagged `blocked_by_gloom` (Study) can't be played while it's set.
- **Why:** The spec's rule and its day 10 / day 11 example, which is a unit test.
- **Next:** Generalize to "conditions" (lockout is one) produced by stat thresholds, which could later include positive states ("Focused: Study +2").

### 3.5 Why a card is blocked
- **Decision:** `block_reason(card)` returns the first reason that applies, in this order: run over, gloom lockout, then no energy.
- **Why:** The spec requires a reason on greyed-out cards. The lockout comes before "no energy" (a milestone 2 change) because once energy runs out, every card would otherwise say "no energy" and hide the more useful lockout message.
- **Next:** Return all reasons for richer tooltips.

### 3.6 When losses happen and how they're shown
- **Decision:** Losses are only evaluated at end of day; going to 0 intellect or 100+ gloom mid-day is allowed. The game-over screen appears right after End Day, after the results popup on days with events, and the day counter doesn't advance.
- **Why:** The spec says a stats loss "shows as a game-over at the start of the next day". Showing it as soon as the day ends is the practical reading: the player never sees a playable next day.
- **Next:** A short "next morning…" transition before the game-over screen would match the spec's wording more literally and add drama.

---

## 4. Events and schedule

### 4.1 Schedule visibility: today plus 3 days
- **Decision:** The "Coming up" strip shows today plus `schedule_lookahead_days` (3) more. The intellect bar also marks the next visible check's requirement.
- **Why:** User decision for milestone 4 ("next few days"). The look-ahead length was an implementation call. The bar marker was added so the requirement versus current intellect gap is visible at a glance.
- **Trade-off:** Players can't plan the whole run. That's intended tension, but it makes an early exam feel like an ambush if the look-ahead is short.
- **Next:** Playtest 3 vs 4 vs 5 days. A run-length calendar showing "an exam happens sometime in days 9–12" without exact days would let players plan without full information.

### 4.2 Random events are surprises
- **Decision:** Random events are rolled at run start (so a seed reproduces them) but never shown ahead of time. They appear as "Surprise!" lines in the end-of-day popup.
- **Why:** User decision for milestone 4.
- **Trade-off:** The player can't play around them, so their gloom is pure risk. The good-player simulator keeps a 15-gloom safety buffer for this reason.
- **Next:**
  - Telegraphed hints ("Mom's been texting a lot…") for some events.
  - Events with choices (accept or decline the Study Group).
  - Weighted pools that change as the run goes on (the spec's "new events joining the pool later").

### 4.3 How many events, and where
- **Decision:**
  - 2 exams, 3 labs (`count_per_run` on each check event), and 3 random events, each drawn evenly from Study Group and Bad News.
  - Day 14 is always an exam (`final_day_event`, which counts toward the 2).
  - No checks before day 5 (`first_check_day`).
  - At most one check per day; random events can land on any day, including check days.
- **Why:**
  - **Counts, final exam and early-day rule:** user decisions for milestone 4. The first check day was originally 3 and moved to 5 during tuning (see 9.2).
  - **One check per day:** an implementation call to keep checks readable and spread out.
- **Trade-off:** Placement is uniform, so checks can bunch up (for example days 13 and 14), and the timing of the second exam is pure luck.
- **Next:**
  - Placement rules with spacing ("at least 2 days between checks"), or a template per run ("midterm in days 6–8").
  - Requirement growth over time (listed in DESIGN.md as "not in MVP"). This is the most important improvement; see 9.3.

### 4.4 Generating the schedule
- **Decision:** `Schedule.generate(config, rng)` builds the schedule from one `RandomNumberGenerator`. It uses its own Fisher–Yates shuffle, because `Array.shuffle()` uses the global random generator and would ignore the run's seed. Overfull configs (more checks than free days) drop the extra checks with a warning instead of crashing.
- **Next:** The spacing and template rules from 4.3, plus a unit-tested "schedule constraints" layer so designers can add rules as data.

### 4.5 One popup for all results
- **Decision:** One end-of-day popup lists each check ("needs X, Kimmy has Y: PASS/FAIL"), each side effect, and each surprise. On a loss, its button leads to the game-over screen.
- **Why:** The spec's presentation requirement: requirement vs stat, and pass/fail.
- **Next:** Animate the comparison (the bar filling to the requirement), and add a run history log so players can review earlier days.

---

## 5. Randomness and seeds

### 5.1 One seed per run
- **Decision:** All randomness in a run comes from the schedule, which is generated from a single seed stored as `run.rng_seed`. Both end screens show the seed.
- **Why:** Milestone 5 asks for reproducible runs. Picking the seed explicitly (`randi()`, then `rng.seed = …`) was necessary because after `rng.randomize()`, the `seed` property doesn't return a value that reproduces the sequence. A test caught that.
- **Next:**
  - **More random systems:** if they're added (random card draws, event rolls at resolution time), derive separate generators from the run seed (seed + stream id) so adding one system doesn't shift another's results.
  - **Shareable runs:** daily seeds, and a seed entry field on the start menu.

### 5.2 Debug fixed seed
- **Decision:** A fixed seed can be set in three ways; the command line takes priority over the data file, and with a fixed seed restarts replay the same schedule:
  - `-- --seed=N` on the command line
  - `debug_seed` in `GameConfig.tres`, where -1 means random
  - the in-game debug menu
- **Why:** The command line suits scripted testing, the data file suits the editor, and the debug menu suits playtests. A test checks that the shipped data never contains a fixed seed.
- **Next:** Record the player's inputs alongside the seed, so a bug report can contain the whole run and be replayed.

---

## 6. Presentation and UI

### 6.1 Placeholder art
- **Decision:** Solid-colored rectangles and panels with labels: Kimmy is an orange block, cards are colored buttons, stats are drawn bars.
- **Why:** The spec ("Placeholder art only").
- **Next:**
  - Real art and audio (listed as not in MVP).
  - Card art scenes (1.2).
  - Kimmy's portrait reacting to gloom and lockout.

### 6.2 Always-visible information
- **Decision:** The top bar shows the day, energy (squares) and the Study streak with its next multiplier. The two stat bars show intellect and gloom: the gloom bar marks the lockout line at 80, and the intellect bar marks the next check's requirement. The yellow banner appears on locked days, and a one-line message says what just happened.
- **Why:** The spec's "always visible" list, plus what helps understanding.
- **Trade-off:** Lots of text; information density is high for a first-time player.
- **Next:**
  - Hover tooltips instead of permanent text.
  - Preview on hover: show the bars' would-be values before a card is played. This is the biggest clarity win available.
  - Accessibility: font scaling, colorblind-safe palette, keyboard and controller input. The spec currently defines mouse controls only.

### 6.3 Cards show their real effect
- **Decision:** Each card shows its cost and its effect *right now*, including the streak (Study shows +11, +12…). A blocked card is greyed out and shows why.
- **Why:** The spec's greyed-out-with-reason rule, plus making the streak legible.
- **Next:** Card layouts with icons instead of text lines, and animated plays.

### 6.4 Custom-drawn stat bars
- **Decision:** `StatBar` draws its own fill, threshold markers (with outlined labels) and text in `_draw()`.
- **Why:** The built-in `ProgressBar` can't draw labeled threshold lines.
- **Next:** Several markers per bar (all visible checks), tweened value changes, and a ghost bar for previews.

---

## 7. Menus and debug tools

### 7.1 Start menu and navigation
- **Decision:**
  - **Start menu:** the game opens on Play / Settings / Quit.
  - **Game screen:** has a Menu button in the top bar.
  - **End screens:** have Restart (or Play again) and Main menu.
  - **Leaving mid-run:** the Menu button drops the run with no confirmation.
- **Why:** The user asked for a start menu; DESIGN.md allows start / game over / win / restart menus.
- **Next:**
  - A confirm dialog before leaving a run.
  - A pause menu.
  - Real settings (audio, fullscreen, text size), saved to `user://`.

### 7.2 Debug config menu
- **Decision:** Settings → **Debug: game config**, shown only in debug builds (`OS.is_debug_build()`).
  - **What's editable:** every exported number and flag on GameConfig, each card and each event. The fields are generated by reflection, so new fields appear automatically.
  - **What's left out:** enums (event kind, which stat is checked) and text, because they're structure rather than balance numbers.
  - **How edits behave:** they change a session copy (`GameSession`, a deep copy of `GameConfig.tres`), apply on the next run, and last until the game closes. Reset to defaults reloads the shipped values.
- **Why:** User decisions: session only, cards and events included, apply on the next run, debug builds only. Using a deep copy (`duplicate_deep(DEEP_DUPLICATE_ALL)`) guarantees the shipped data can't be changed by accident; tests check this.
- **Trade-off:** Good values have to be copied into the `.tres` by hand, and you can't change rules mid-run.
- **Next:**
  - "Export to .tres" / "Copy as `--set` arguments" buttons.
  - Named presets.
  - A "Run simulator" button that shows win rates for the current edits right in the menu.

---

## 8. Testing

### 8.1 GUT, headless
- **Decision:** GUT 9.7.1 (the release built for Godot 4.7's stricter return types) is copied into `addons/gut`. The tests run headless with one command.
- **Why:** User choice (GUT over gdUnit4). Copying the addon into the repo pins the version.
- **Next:**
  - **CI:** a GitHub Actions workflow that downloads Godot 4.7.2, imports the project, and runs GUT on every push. This is the highest-value tooling addition.
  - **Visual checks:** screenshot comparison tests for UI layout.

### 8.2 What the tests cover
- **Decision:** 99 tests across six files:
  - data integrity
  - every rule in DESIGN.md (including its examples)
  - schedule properties checked across 300 seeds
  - UI tests that load the real scenes and press their buttons
  - menus and the debug menu
  - simulator correctness, plus a balance guard

  Tests guard against "orphan" nodes left behind; display-only nodes are freed immediately to keep that clean.
- **Next:** Coverage reporting, and performance budgets for the simulator.

### 8.3 Rule tests use their own config
- **Decision:** Rule tests use `TestFixtures.rules_config()`, a config pinned to DESIGN.md's original numbers. Only `test_data.gd` checks the shipped values.
- **Why:** When tuning changed the shipped numbers in milestone 6, 20 rule tests broke for no rule reason. Separating them means retuning only touches `test_data.gd` (and the balance guard if the target band moves).

### 8.4 Balance guard
- **Decision:** A test fails if the good player's win rate on the shipped data leaves 60–80%, or if always-Study wins 5% or more.
- **Why:** Stops a casual data edit from quietly breaking the game's difficulty.
- **Trade-off:** It adds about 3 seconds to the test run, and it will fail on intentional rebalancing (update the band and BALANCE.md together).

---

## 9. Balance and tuning

### 9.1 Simulator-driven tuning
- **Decision:** A headless simulator (`tools/sim/`) plays seeded runs with four strategies: good, pattern, always_study and random. The good player tries every card sequence each day, scores the results like a cautious human, and sees only what a human sees.
- **Why:** The user chose a target of a good player winning about 60–75%. A simulator turns "winnable but tense" into numbers you can reproduce.
- **Trade-off:** The good player is a heuristic, not an optimal player, and it plans only one day ahead. Its weights hardly change results (tested), which suggests the remaining losses are mostly decided by the schedule rather than by play.
- **Next:**
  - **An "oracle" player** that sees the full schedule, to measure how many seeds are truly unwinnable. That would separate unfairness from difficulty.
  - **A stronger planner:** search several days ahead, or expectimax over hidden events.
  - **Better reporting:** CSV output and an automatic parameter sweep.
  - **Calibration:** check human playtest results against the bot's.

### 9.2 Tuned values
- **Decision:**

  | Value | Before | After |
  |---|---|---|
  | Exam requirement | 50 | 100 |
  | Lab requirement | 35 | 65 |
  | Lab gloom | +10 | +15 |
  | Start gloom | 20 | 25 |
  | First check day | 3 | 5 |

  Cards and the streak are unchanged. Result: the good player wins 71.9% and the pattern player 49.5%, and random play never wins.
- **Why:** These are placeholder values first, per the user. The first check moved to day 5 because with day 3, more than half of losses were exams on days 3–4 that were out of reach for any strategy. Full data is in [BALANCE.md](BALANCE.md).
- **Trade-off:** About 8% of runs are still lost to an exam on exactly day 5. Some are probably unwinnable.
- **Next:** The human playtest from milestone 6. If testers find early losses unfair, try `first_check_day = 6` or an exam requirement of 95.

### 9.3 Main finding: the late game has little tension
- **Finding:** Intellect never goes down and requirements never change. Once Kimmy clears the exam bar, every later check is already passed, and Game ×3 removes 18 gloom a day at no cost. So losses cluster in days 5–9, and days 10–14 are mostly a victory lap. **No set of numbers fixes this; it needs a rule change.**
- **Next:** Candidate rule changes, best fit first:
  1. **Requirements that grow** (the spec's "not in MVP" item): each check asks for more than the last, for example +10 per occurrence, or scaling with the day.
  2. **A distinct final exam** with its own, higher requirement on day 14.
  3. **Gloom drift:** +N gloom every day on its own, so Game stops being free maintenance.
  4. **Intellect decay:** a little intellect lost per day without Study.
  5. **The streak carrying across days** (an open question in the spec), to reward commitment.

  Each one can be tried in the simulator before any UI work.

---

## 10. Known gaps
- **Not in the MVP, by spec:** saving mid-run, audio, real art, and keyboard or controller input.
- **No export presets yet:** the Windows and Linux builds that DESIGN.md targets aren't set up.
- **No confirmation** when leaving a run from the Menu button.
- **Quit button on web:** it would do nothing in a web build (not a target).
- **Omitted default:** `GameConfig.tres` leaves out `intellect_loss_threshold = 0` because it equals the default (see 2.1).
- **Simulator limits:** results describe a heuristic bot. They haven't been checked against human play yet.

---

## 11. Roadmap
Suggested order for further development. Each item names the decisions above it builds on.

| # | Item | Builds on | Why now |
|---|---|---|---|
| 1 | **Human playtest** (DESIGN.md "Done when") | 9.2 | Confirms the bot's numbers and the UI's clarity before more features are built |
| 2 | **CI** running GUT on push | 8.1 | Cheap, and protects everything below |
| 3 | **Export presets** for Windows and Linux | 10 | The spec's target platforms; needed to hand builds to testers |
| 4 | **Late-game tension rule** (growing requirements first) | 9.3, 4.3 | The biggest design weakness; try it in the simulator first |
| 5 | **Hover previews and tooltips** | 6.2, 6.3 | The biggest clarity win for new players |
| 6 | **`DayResult` class and finer signals** | 1.1, 1.4 | Groundwork for animation and the effect system |
| 7 | **Effect system and stat definitions** | 2.2, 3.1 | Unlocks more cards, temporary effects and more stats |
| 8 | **Schedule spacing and templates; event choices** | 4.2, 4.3 | Richer runs once the effect system exists |
| 9 | **Debug menu export and in-menu simulator** | 7.2, 9.1 | Faster tuning loop for the larger content set |
| 10 | **Real art and audio, card scenes, animation** | 1.2, 6.x | Once the rules settle |
| 11 | **Command log: replays, undo, save-anywhere** | 1.1, 5.2 | Bug reports and mid-run saving |
