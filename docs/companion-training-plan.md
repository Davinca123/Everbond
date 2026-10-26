# Plan: companion skills and training

The companion learns skills, and each skill gets better with training. This plan covers:

1. **Send and stay** (sections 1–3): sending the companion to a tapped spot, how long it stays there, how far it can be sent, and a new call-back button.
2. **New skills** (sections 4–7): pull, the other interaction skills (push, scratch/cut, carry), mind swap and spelling.
3. **Training and the skill tree** (sections 8 and 10): active training sessions, different for each skill, and a skill tree where every upgrade has a requirement to complete instead of a skill point to spend.
4. **Practice** (section 9): the companion's dexterity and attention. A beginner companion is clumsy and easily distracted, and gets better with practice. This is separate from training.

The challenges the skills are meant for aren't designed yet. The skills come first, and the puzzles that use them will follow.

## Where things stand

- **Done:** bug #16 is fixed (`fix/companion-unreachable-target`). `send_to_position()` snaps the tapped point to the end of the companion's navigation path on its level (`get_reachable_point()`), so the marker, the walk and the arrival check all use the same point.
- `companion.gd` has an exported `stay_duration` (default 2 s). `send_to_position()` walks the companion to the tapped spot, it waits `stay_duration`, then goes back to following. A new tap at any time sends it somewhere else.
- The grey countdown line above the companion scales to `stay_duration`, so it needs no changes for training.
- `PlayerData` has `companion_obedience` (starts at 1) and `companion_unlocked_skills`, and `SignalBus` has `companion_obedience_changed`. None of them are used yet.
- There is no save system, so `PlayerData` resets each time the game starts.
- There are no treats, no skill tree UI and no interaction skills yet.

## 1. Send range

**Rule:** the companion's destination must stay within the send range of the player's feet, measured as a straight line. The range is checked continuously, not only at the tap: when the player moves, the destination moves with them.

**Destination while walking:** the companion keeps the original tap point `T`. Each time it recalculates its path (every 0.25 s, as it does today), it works out its destination from the player's current feet position `P` and the current range `R`:

1. If `T` is within `R` of `P`, the destination is `T`.
2. Otherwise it's the point on the edge of the range circle, toward the tap: `P + (T - P).normalized() * R`.
3. That point is snapped to the nearest reachable point (`get_reachable_point()`).

**What this means in play:**
- The marker is always drawn at the current destination, so it slides along as the player moves. If the player walks back toward the tap, the destination moves back toward `T`, up to `T` itself.
- While walking, the companion chases the moving destination. The player is faster (200 vs 160), but the destination itself never leaves the range.
- **During the wait:** if the player moves but the companion is still within range, it keeps waiting. If the player moves out of range, the companion cancels the wait at once and comes back. The countdown line disappears, and the wait isn't resumed if the player comes back. The send range training (section 8) is the exception: there, the companion sometimes stays.
- **Tolerance:** "out of range" during the wait means farther than `R` plus a small tolerance (placeholder 40 px). The snap can leave the destination slightly past `R`, for example when the circle edge is inside a wall. Without the tolerance, the companion would give up the moment it arrived.

**Range values:** the range comes from `PlayerData` and is trained (section 8). Placeholder base value: 500 px. At the default zoom, the screen is 2400 px wide, so half the screen is 1200 px. That means a tap near the screen edge gets clamped at the starting level. The companion reads the range every time it uses it, so a new level takes effect immediately, even mid-walk.

**Why a straight line rather than walking distance:** it's a simple circle around the player that's easy to understand and could be drawn later. Walking distance would make the same tap behave differently depending on walls between the player and the target.

Branch: `feat/companion-send-range`.

## 2. One send, then back: the new stay rule

Today a tap sends the companion anywhere at any time. The new rule makes a send a commitment:

1. **Send:** the player taps a spot, and the companion walks there (within the send range).
2. **Stay:** it waits there until its stay time runs out, or until the player calls it back.
3. **Return:** it walks back to the player and goes back to following.
4. **Ignored taps:** from the send until it is back at the player's side, every other tap is ignored. A tap that's ignored could show a short "no" reaction on the marker or the companion, so the player knows it was heard.

**Call back:** a new on-screen button, shown only while the companion is walking to a spot or waiting there. Pressing it ends the wait at once, or turns the companion round if it's still walking there, and it returns. A new `SignalBus.companion_recalled` signal, emitted by the button, the same way the touch UI sends its other inputs.

**"Back at the player's side":** within the follow distance it uses today, so the next send is possible as soon as it falls into step behind the player.

**Training: more waypoints per send.** A trained companion takes more than one waypoint before it returns. At level 1 it takes 2 waypoints: the first tap sends it, and while it's out, one more tap is accepted and queued. It walks to the first spot, stays, walks to the second, stays, then returns. Each level adds one more waypoint. The queued spots are drawn as markers, numbered or linked by a faint line. Calling back clears the queue. How it's trained is open (see [open questions](#open-questions)).

**What happens to the send range with several waypoints:** each waypoint is clamped to the range from the player's position when the companion sets off toward it, and then follows the player as in section 1.

Branch: `feat/companion-send-once`. It changes the same code as the send range, so it comes after it.

## 3. Stay time

The stay time is how long the companion waits at a spot before it returns by itself. When the companion arrives at a spot, it reads `PlayerData.get_companion_stay_duration()` into `stay_duration`. A new stay level therefore applies from the next wait, and a wait already counting down isn't changed, except by the treat throw in the stay training (section 8).

## 4. Pull

The companion pulls levers, crates and similar objects up, down, left or right.

**Gesture:** the player swipes from the object in the direction of the pull. The swipe has to start on the object; its direction is snapped to the nearest of the four directions. A short swipe that doesn't start on a pullable object is treated like a tap, as today.

**Pullable objects:** a new `pullable` group (or a `Pullable` base script) with `can_pull(direction) -> bool` and `pull(direction)`. A lever toggles; a crate moves one step (a tile, or a fixed distance) if the cell behind it in that direction is free. Each object decides which directions it accepts: a lever might only go up and down.

**The companion doesn't travel for a pull.** It pulls from where it stands, so the pull reach is a circle around the companion, not the player. If the animation needs it to step toward the object (to grab a rope or the handle), it goes back to the same spot afterwards. A pull doesn't count as a send, and it doesn't end a wait: a companion sent to a spot can pull things from there, which is how the reach and the send range work together.

**Reach circle:** a pale circle around the companion shows its pull reach. It appears while an interaction is being asked for: from the moment a finger lands on a pullable object until the swipe ends. Objects inside the reach that the companion can see could be lightly highlighted at the same time.

**What the companion can pull, by level:**

| Level | Reach | Must it see the object? |
|---|---|---|
| 0 | small circle (placeholder 120 px) | yes |
| 1–n | the circle grows (placeholders 200, 300, 450 px) | yes |
| next | no limit | yes |
| last | no limit | no, but it must be able to reach it |

**Seeing an object** means both:
- It's on the companion's level (`Lenti_Szint` / `Fenti_Szint`), the same level check the navigation uses.
- Nothing is in the way: a ray from the companion's feet to the object doesn't hit a wall or another obstacle on that level's collision layer. The object's own collision is excluded from the ray.

**Reaching an object it can't see** (the last level) means there's a navigation path on its level from the companion to the object (`get_reachable_point()` ends next to it). For example, a lever behind a wall, round the corner of a corridor. The companion goes there, pulls, and comes back to its spot.

**Feedback when a pull is refused:** the circle flashes, and the companion shakes its head or looks at the object. Reasons: out of reach, not seen, or the object can't be pulled that way.

Branch: `feat/companion-pull`. The reach and sight check go in a helper that the other interaction skills reuse.

## 5. Other interaction skills

Push (a button), scratch or cut (a rope, bushes), carry (an item), and more later. They follow the same pattern as pull:

- each has its own gesture (for example, tap for push, a zig-zag for scratch, drag-and-drop for carry),
- each has its own reach levels and sight rules, using the same helper as pull,
- each has its own group for the objects it works on.

Only pull is planned in detail. The others get their own sections when they're designed.

**Carry and the form change:** the companion learns to carry things in form 2, holding them in its mouth or arms. When it grows into form 3 ([forms](companion-nature.md#8-forms)), carrying changes: it swallows the thing and spits it out where it's sent. Ideas this opens up:

- **No dropping:** a swallowed thing can't be dropped by accident, so the carry mishap from practice (section 9) changes: it hiccups or burps the thing out early instead. Still cute, still a mishap.
- **Carrying through danger:** a swallowed thing is safe through water, fire or a crowd of enemies; a lit torch stays lit under water.
- **Spitting is throwing:** it can spit the thing a short way, across a gap or up onto a ledge, which carrying in its mouth couldn't do. A new puzzle element.
- **Bigger or more things:** it may swallow bigger things, or a few at once, spat out in order.
- **Nature and mood:** some things it refuses to swallow because they're yucky (a picky companion refuses more). A tasty thing, like a cookie, may get eaten for real by a hungry or selfish companion: "Oops."
- **Puzzles both ways:** world puzzles that need spitting are one more reason to come back after form 3; dungeons before form 3 must not need it.

Note bugs #4 and #5 in `BUGS.md`: interactables share one button and one signal today. The interaction skills go through gestures and their own groups, so they don't add to that, but the shared button should be fixed before more objects rely on it.

## 6. Mind swap

For a few seconds the player and the companion swap roles:

- The joystick moves the companion, and the camera follows it.
- A tap sends the player to a spot, the same way taps send the companion today: the player walks there by navigation, with the same send rule (section 2) and the same markers.
- When the time runs out, control swaps back. The countdown is shown on screen (a bar or a ring on the skill button).

**Starting it:** a skill button, shown once the skill is unlocked. Pressing it again ends the swap early.

**Training:** the duration grows. Placeholder levels: 5, 8, 12, 20 s.

**Needs:** the player gets the navigation and tap-to-send code that the companion has today. That code should move into a shared component that either character can use, rather than being copied.

**Open:** what the swap is used for, what the send range is measured from during the swap (the companion, the controlled character), and what happens if the time runs out while the player is walking somewhere.

Branch: `feat/mind-swap`, after the send rule (section 2).

## 7. Spelling

A stub for now: a skill named in the skill tree, with no gameplay yet.

## 8. Training

Training is an active session: the player does a specific task with the companion, and each skill's task is different. A task usually has to be repeated a number of times (10, 20, …). When it's done, the skill gains a level, and the skill tree shows the next requirement.

**Treats:** most tasks reward the companion with a treat. Two ways to use one:
- **Give:** when the companion is next to the player, a "treat" button gives it one.
- **Throw:** the player throws a treat at a spot (for example, a swipe from the player toward the companion). It hits if it lands close to the companion.

Treats are an item; whether they're limited is open.

**Example tasks:**

- **Send range, step 1:** send the companion to the edge of the send range, wait for it to come back, and give it a treat. Repeat it 10 / 20 / … times.
- **Send range, step 2:** "Send the companion to the edge of the range, and when it gets there, walk away in the opposite direction. There's an x% chance it stays where it is. If it does, give it a treat, and the send range grows." This is the one case where the companion ignores the out-of-range rule from section 1. If it doesn't stay, it comes back as usual and the attempt doesn't count.
- **Stay time:** "Send the companion to a spot. When it gets there and the countdown is almost over, throw it a treat. If it hits, there's a good chance it stays for another countdown. If it does, wait for it to come back, then give it a treat."
- **Waypoints per send, pull reach, mind swap duration:** not designed yet.

**Chances:** each try at a task that has a chance (x%) rolls once. The chances are placeholders, and might go up with each failed try so the player isn't stuck on bad luck.

**Data in `PlayerData`:**
- A level and a progress counter per skill: `companion_skills = { "range": {"level": 0, "progress": 0}, "stay": {...}, "waypoints": {...}, "pull": {...}, "mind_swap": {...} }`.
- Level tables for each skill (placeholders to tune):
  - `COMPANION_STAY_DURATIONS = [2.0, 3.0, 5.0, 8.0, 12.0]` (seconds)
  - `COMPANION_SEND_RANGES = [500.0, 650.0, 800.0, 1000.0, 1200.0]` (pixels)
  - `COMPANION_WAYPOINTS = [1, 2, 3]`
  - `COMPANION_PULL_REACHES = [120.0, 200.0, 300.0, 450.0, INF]`, then a flag for the "doesn't need to see it" level
  - `MIND_SWAP_DURATIONS = [5.0, 8.0, 12.0, 20.0]` (seconds)
- A getter for each value, such as `get_companion_send_range()`.
- `add_training_progress(skill)` counts one successful repetition, and `level_up_skill(skill)` raises the level and resets the counter. Each emits `SignalBus.companion_skill_changed(skill, level, progress)` (a new signal), which the skill tree listens to.
- `companion_unlocked_skills` says which skills are available at all; `companion_obedience` stays free for something broader.

**Where the tasks live:** each task is a small script that listens to companion signals (arrived, returned, treat hit, …) and calls `add_training_progress()`. This keeps training out of `companion.gd`. The companion only needs to emit those signals.

Branch: `feat/companion-training`, with one branch per skill's task after it.

## 9. Practice: dexterity and attention

Training and practice are two different things:

- **Training** builds the bond between the player and the companion: the companion learns the commands and requests, and how far, how long and how many it will do (section 8).
- **Practice** develops the companion's own dexterity and attention: how well it carries out a command it already understands.

At first the companion is clumsy. It knows what's asked, but it doesn't always manage it.

**Mishaps, by skill:**

- **Walking to a waypoint (send):** it doesn't walk straight and fast to the spot. It sets off in a wrong direction, then usually finds the real spot, but sometimes doesn't: it stops somewhere else, or gives up and comes back.
- **Stay:** it gets distracted, for example by a butterfly, and wanders off the spot. It might come back to the spot by itself, or need calling back.
- **Push and pull:** it misses the object (nothing happens), or pulls it in the wrong direction. It can even hurt itself.
- **Carry:** it drops what it carries by accident (in form 3, it hiccups it out early instead; see section 5).

**Two stats:** dexterity (missing, wrong direction, hurting itself, dropping things) and attention (wrong direction on the way, distractions during the stay). Each mishap reads one of them. Both start low and grow with practice.

**How a mishap is decided:** each mishap has a chance, worked out from the stat and the companion's mood (see below). It's rolled at fixed moments, not every frame:
- when the companion sets off toward a waypoint (wrong direction or not, and whether it finds the spot again),
- every few seconds of a stay (distracted or not),
- at each push or pull (miss, wrong direction, hurt),
- every few seconds of carrying (drop or not).

**What the mishaps look like in the code:**
- **Wrong direction:** the companion first walks to a detour point off to the side of the real path, then paths to the real spot. If the "finds it" roll fails, its destination is replaced by a nearby reachable point instead.
- **Distraction:** a distraction (a butterfly, a smell) appears near the companion, and the companion follows it for a moment. Its stay countdown keeps running. When the distraction is over, it either walks back to the spot or stays where it ended up.
- **Wrong direction on a pull:** only toward a direction the object accepts, so a mishap can't do something the object doesn't allow. For a puzzle, a wrong pull can still be a setback (a crate in the wrong place), so crates need a way to be reset.
- **Hurt:** a yelp, a short pause in which it doesn't take commands, a drop in mood and some health (see [the companion's nature](companion-nature.md)).

**How practice is gained:** by doing. Every send, stay, pull or carry counts toward its stat, whether it went well or not, so practice grows naturally while playing and during training. The details are open.

**Practice and training together:** training tasks still count only successful tries, so a clumsy companion makes training slower. A mishap during a training task makes that try fail, but it still counts as practice.

**Mood:** the companion also has a mood, which changes how it responds to tasks: a happy companion makes fewer mishaps, a grumpy or tired one more. The mood stat, and the rest of the companion's nature, are described in [the companion's nature](companion-nature.md). Here, mood is only one input to the mishap chances. Mood, stubbornness and needs can also make it refuse a command it has fully learned (section 5 of that document).

**Data in `PlayerData`:** `companion_dexterity` and `companion_attention` (floats from 0 to 1, or levels, to be decided), with `add_practice(stat, amount)` and a `SignalBus.companion_practice_changed(stat, value)` signal, the same way as the skill data.

Branch: `feat/companion-practice`, after the training data. Each mishap could go in with the skill it belongs to: the walk and stay mishaps first, the pull ones with the pull skill.

## 10. Skill tree

A screen that shows every skill and its levels. There are no skill points: each upgrade has a requirement, the training task for that level.

- Each skill shows its current level, the next level's value (for example "Send range: 650 → 800"), the task text, and the progress ("7 / 20").
- When a task is done, the text changes to the next level's task.
- Some upgrades could also need another skill to reach a level first, for example pull reach "no limit" after a certain send range. The tree's links show these.
- Locked skills (mind swap, spelling) show what unlocks them.
- Practice (section 9) isn't a skill and has no requirements. The skill tree, or the companion's own screen, can show the dexterity and attention stats as bars.

Branch: `feat/skill-tree`, after the training data.

## 11. Tests

Add these to `test/tap_test.tscn`, through the real input pipeline:

- **Tap inside range:** the destination is the tapped point, unchanged.
- **Tap beyond range:** the destination is on the range circle, toward the tap (within the snap allowance), and the marker is drawn there.
- **Player moves while the companion walks:** the destination and the marker move with the player and stay within range. When the player walks back toward the tap, the destination returns to the tap point.
- **Player moves within range during the wait:** the companion keeps waiting until the countdown ends.
- **Player leaves the range during the wait:** the companion cancels the wait in the same moment and comes back. The countdown line disappears.
- **One send:** a second tap while the companion is out is ignored, until it's back at the player's side.
- **Call back:** pressing the button during the walk and during the wait brings the companion straight back.
- **Waypoints:** at level 1, a second tap is queued, both spots are visited in order, and a third tap is ignored.
- **Pull:** a swipe on a lever in reach pulls it; out of reach, behind a wall, or on the other level it's refused; at the last level, a lever behind a wall is reached by walking and the companion comes back to its spot.
- **Training levels:** at each level, the stay time, range, reach and swap duration match the tables. Raising the range level mid-walk moves the destination out right away.
- **Training tasks:** a script that plays each task through and checks the progress counter and the level-up.
- **Practice:** tests run with dexterity and attention at the maximum, so the other tests have no mishaps. Separate tests force each mishap (a chance of 1) and check what happens: the detour on the way, a distraction during the stay, a missed and a wrong-direction pull, and a dropped item.

Also re-run the level-following scenarios in `test/drive.tscn`.

## Order of work

1. ✅ `fix/companion-unreachable-target`, for bug #16.
2. `feat/companion-send-range`.
3. `feat/companion-send-once`: one send, call back, ignored taps.
4. `feat/companion-training`: skill data in `PlayerData`, treats, the first tasks (range and stay).
5. `feat/skill-tree`.
6. `feat/companion-practice`: dexterity and attention, the walk and stay mishaps.
7. `feat/companion-pull`, with its level of the tree, its task and its mishaps.
8. `feat/mind-swap`.
9. Further interaction skills and spelling, when designed.

Each branch is made from `dev` and merged back with `--no-ff`, as in `CLAUDE.md`.

## Open questions

- **Training tasks not yet designed:** waypoints per send, pull reach, mind swap duration, and the repetition counts (10 / 20 / x) and chances (x%) for every task.
- **Treats:** limited or unlimited? How are they got? Exactly how is a throw aimed, and what counts as a hit?
- **Pull animation:** does the companion pull from where it stands (a rope, a magic tug) or step over and come back?
- **Pull reach circle:** shown only while a swipe is being made on an object, or also when the player taps a "pull" skill button?
- **Crates:** how far does a pull move them, and can a crate be pulled toward the companion onto its own spot?
- **Mind swap:** what it's for, and the details in section 6.
- **Tolerance during the wait:** 40 px is a placeholder. A larger value makes the companion less twitchy when the player stands near the edge of the range.
- **Show the send range?** For example, a faint circle while tapping, or a brief flash when a tap gets clamped.
- **Practice:** how much each action adds, whether the stats are smooth values or levels, and whether practice can be lost without use.
- **Mishap chances:** how dexterity, attention and mood combine into a chance, and how often each roll happens.
- **Values:** every level table is a placeholder to tune in playtesting.
- **Saving:** skill levels and progress are lost on restart until a save system exists. `PlayerData.companion_skills` can be written out as it is, like `GameManager.map_state`.
- **Taps across levels:** tapping a spot under a bridge while the companion is on top still isn't routed through the entrance. That's out of scope here.
