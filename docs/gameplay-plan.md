# Plan: gameplay

What the player does in Everbond, and how the parts fit together. The game is about the relationship with the companion and the story. Puzzles are the main challenge; combat is light and stress-free. Like everything else, the gameplay follows the [cute and joyful tone](companion-nature.md#tone-cute-and-joyful).

Related: [companion skills and training](companion-training-plan.md), [the companion's nature](companion-nature.md), [map structure](map-structure-plan.md).

## Where things stand

- The player walks with a joystick (or the keyboard), and the companion follows, can be sent to a tapped spot, and waits there.
- Maps: World, Town and one house interior, joined by doors and edge exits. Doors can be locked (`door.gd` has `is_locked` and a key check), and opened doors stay open.
- NPCs have a fixed list of lines and a dialogue box.
- `PlayerData` has player health (`take_damage()`, `heal()`, `player_died`) and gold. There's an attack button image in `scenes/ui/`, but no combat, enemies or weapons yet.
- No story, quests, inventory UI or save system yet.

## 1. Pillars

1. **The companion relationship:** the bond, conversations, training and care (see the other two plans).
2. **The story:** told through NPCs and conversations. The story moves forward when the player talks to the right people.
3. **Puzzles:** small ones on the world map, big ones in dungeons and boss fights, almost all solved together with the companion.
4. **Light combat:** easy, needs little gaming skill, never the reason the player gets stuck.

**The world opens up area by area,** as the story moves on. A new area is reached through a story beat, a dungeon, or a puzzle that needs a new skill.

**The loop:** explore → meet NPCs and follow the story → find puzzles, some too hard for now → train and bond with the companion → come back and solve them → reach a dungeon → its puzzles and boss → the next part of the story, a new form or skill.

## 2. Combat

Easy and stress-free. A player who isn't good at action games should still enjoy every fight.

**The companion fights by itself.** When enemies are near, it picks a target and attacks without being asked. Its brain (nature plan, section 10) decides how:
- an eager or persistent companion charges in,
- a lazy one attacks less often,
- a fearful one stays near the player but still helps (it's never useless),
- at a high bond it protects the player, putting itself between the player and an enemy.

Its attacks are cute (a puff of fire, a pounce, a tail swipe) and its damage grows with its form. Sending it to a spot with a tap still works in a fight, to pull it out or point it at an enemy.

**The player has one weapon,** a sword (or a stick at first). One attack button, one simple swing. Maybe a charged swing by holding the button. Upgrades make the sword stronger and change its look, but there are no other weapon types to learn. Tools that help puzzles (section 4) aren't weapons.

**Enemies:**
- Cute: slimes, grumpy mushrooms, mischievous critters.
- Slow, clearly shown attacks (a wind-up the player can see), so getting out of the way is easy.
- Defeated enemies don't die: they poof into a puff of stars, or run away crying, or calm down and wander off.
- Few at a time.

**Health and losing:**
- Player health is generous and refills slowly outside combat. Food and potions heal.
- At 0 health the player faints and wakes up at home (section 7), or at the map's checkpoint if there are checkpoints (still open), with the companion beside them, worried. Nothing is lost.
- The companion's own health and fainting are in the nature plan (section 3).

**Combat and the bond:** the companion cheers after a fight, comments on how it went, and remembers big fights. Fighting together is one of the things that raises the bond.

**Options:** an "easy" setting that makes enemies weaker still, or lets the player skip a fight that's blocking them.

## 3. World map puzzles

Small puzzles in the world, solved with the companion's skills:

- a lever behind a fence that only the companion can reach (pull),
- a pressure plate that has to stay pressed while the player crosses (send and stay),
- a crate to pull out of the way (pull),
- a rope or bush to cut (scratch/cut), an item to carry across a gap (carry),
- a spot the companion can see but the player can't get to.

**Coming back later:** some puzzles need a skill level the companion doesn't have yet: a longer send range, a longer stay, a pull reach that sees round corners. The player finds them early and comes back after training, like in a Metroidvania.

- **The companion notices:** when the player finds a puzzle that's too hard for now, the companion says so ("I can't reach that… yet!"). The spot is marked on the map and in a list.
- **The companion remembers:** when it reaches the needed level, it reminds the player ("Remember the lever by the river? I bet I can pull it now!"). This uses its memory log (nature plan, section 4).
- **Rewards:** treats, items, gold, shortcuts between areas, scrapbook entries, bits of story or lore.
- **Never required for the main story,** unless the story itself leads there. World puzzles are optional rewards; dungeons are where the required puzzles are.

## 4. Dungeons

Puzzle dungeons, in the style of CrossCode: a series of rooms, each a puzzle, joined by doors.

- **A theme for each dungeon:** a look, a tile set and a main puzzle idea (water levels, light and shadow, moving platforms, two floors).
- **Puzzles with the companion:** the same skills as on the world map, combined in bigger ways. The player and the companion often have to split up: the companion holds a plate on one side while the player goes through on the other.
- **Something new in each dungeon:** a training milestone, a new skill, a new tool or a new puzzle element appears in the dungeon and is used in the rest of it, as in Zelda and CrossCode.
- **Puzzle elements:** levers, crates, pressure plates, buttons, ropes, carriable items, keys and locked doors (`door.gd` already has `is_locked`), bridges and the two levels (`Lenti_Szint`, `Fenti_Szint`), switches the companion has to reach without seeing them, and mind swap rooms (the player and the companion in two places at once).
- **Resetting:** every room can be reset to its starting state (a crate pulled the wrong way by a clumsy companion mustn't trap the player). Leaving and re-entering the room, or a reset switch.
- **Hints:** if the player is stuck for a while, the companion gives a hint, first a vague one, then a clearer one. The player can turn this off.
- **A map of the dungeon** and checkpoints at the entrance and before the boss.

## 5. Boss fights

Bosses are puzzles more than fights:

- The boss has a pattern to figure out, and a way to make it vulnerable that uses the companion's skills: pull a chain to drop a cage, send the companion to distract it while the player hits a switch, make it charge into a wall.
- A few phases, each adding a twist to the same idea.
- Little damage, slow attacks, a checkpoint at the boss door.
- Bosses are cute too, and often not really evil: after the fight, a boss can be calmed down, befriended, or turn out to have been under a spell.
- The companion talks during the fight: it reacts, gets scared or excited, and hints at the trick if the player struggles.

## 6. NPCs and the story

The story moves forward through NPCs and conversations:

- **Quests come from conversations:** an NPC asks for help, or mentions something that points the player somewhere. There's no big quest log; a short list of current goals is enough.
- **The companion helps with the story:** it chats with NPCs it likes and brings back clues (nature plan, section 6), and in some scenes it's the one who notices what's going on.
- **Story moments are relationship moments too:** big story beats come with a conversation with the companion, and some bond thresholds or form changes happen at story points.
- **NPCs remember:** what the player and the companion did for them, and how the companion behaved (a cheeky companion may have upset someone).

## 7. Home

The player has a home, a small house or a tent, which is the one place where the game is always saved.

- **Saving:** the game saves when the player rests at home. It's the absolute save point: whatever else happens, the player can always go back to it.
- **Customising:** the player decorates it with furniture and decorations found or bought.
- **The companion's corner:** its bed or nook is here (nature plan, section 9). It naps there, it's the coziest place for its mood, and it decorates it a little by itself with things it found.
- **Home life:** feeding, washing and resting the companion happen most naturally here, and many relationship conversations happen by the fire in the evening.
- **Moving home:** as the world opens up, the home might move with the player (a tent is easy to carry), or there could be a fast way back. Open.

**Checkpoints per map:** maybe. If there are any, they're only where the player wakes up after fainting, not save points. Dungeons have checkpoints at the entrance and before the boss either way.

## 8. Progression

What opens up the game:

| What | Comes from | Opens |
|---|---|---|
| Story beats | conversations, dungeons | new areas, new NPCs, dungeons |
| Training levels | training sessions | world puzzles, shortcuts, dungeon rooms |
| Practice | doing things | fewer mishaps, smoother puzzles |
| Bond | conversations, care, training, conflicts and making up | fewer refusals, skill upgrades, forms, relationship scenes |
| Forms | milestones of story, bond and training | stronger and cooler companion, new lines |
| Sword upgrades | dungeons, shops, quests | a little more damage |

## 9. Controls (touch first)

The game is played on a phone first, so the screen must stay simple:

- joystick: walk,
- attack button: swing the sword,
- interaction button: talk, open, pick up (context-dependent, shown only when there's something to do),
- tap: send the companion,
- swipe from an object: pull (and other skill gestures),
- call-back button, talk-to-companion button, pet: small buttons near the companion's portrait.

Buttons appear only when they can be used. The keyboard and mouse work too: E, Space or Enter is the interaction button, and a mouse click is a tap.

## 10. First playable slice: the dragon and the gate

A short scene in World that shows the main pillars together: sending and stay, a puzzle with the companion, training with treats, a companion that talks and has a mood and a bond. If this feels cute and alive, the rest of the plans are mostly more of the same; if it doesn't, it shows early and cheaply.

The foundations it builds on are done: dialogue on PC (bug #3), one interaction manager (bugs #4–#6) and English/Hungarian texts (`feat/localization`).

### The scene

1. The Old Sage mentions an old gate east of him: "It only opens while someone stands on the stone in front of it."
2. The player finds the gate. Behind it is a chest. In front of it is a pressure plate, a few steps away.
3. The player stands on the plate: the gate opens, but closes as soon as they step off. They send the companion onto the plate instead and run for the gate.
4. The companion's stay time (2 s at the start) is too short: the gate closes before the player gets through. The companion says something about it ("I can't hold it that long… yet!").
5. Next to the gate there's room to train. The companion suggests it, or the Sage does. The task: send the companion, let it wait the whole time, and when it comes back by itself, give it a treat. Five times.
6. After the fifth treat the stay level goes up (2 s → 3 s). The companion celebrates.
7. The player tries again and gets through. A latch on the far side keeps the gate open for good, so the companion can follow. The chest holds more treats.
8. All along, the companion talks: when it's sent, when it arrives, when it's called back, when it gets a treat, when it's bored. Its mood and bond go up with the treats and the success.

The numbers (stay time, the gate's opening time, the doorway's depth, number of treats) are tuned so that stay level 0 just fails and level 1 just works.

### Steps

Each step is its own branch from `dev`, merged back with `--no-ff`, with its own tests. The order matters: each one uses the ones before.

**1. ✅ `feat/companion-send-range`**: the send range from the training plan (section 1).
- The destination is clamped to the range around the player (placeholder 500 px) when tapped, and then stays where it is. If the player walks off so far that it falls outside the range (plus a 40 px tolerance), the companion turns back at once. (At first the destination followed the player; it was changed so the spot stays exactly where it was tapped.)
- A faint circle around the player's feet shows the range (`scenes/player/send_range_circle.gd`).
- During the wait, the companion gives up and comes back if the player goes out of range (plus a 40 px tolerance).
- The range comes from `PlayerData.get_companion_send_range()`, range level 0 for now. Tests that check path finding to far spots set `PlayerData.companion_send_range_override`.
- Tests in `test/tap_test.gd`: tap inside and beyond the range, the player moving while the companion walks, the player leaving the range during the wait (the cases listed in the training plan, section 11).

**2. ✅ `feat/companion-send-once`**: one send, then back (training plan, section 2).
- While the companion is walking to a spot, waiting or coming back, other taps are ignored. With the infinite stay test toggle the sends are unlimited too: a new tap sends the companion to the new spot at once. An ignored tap gets a short reaction on the companion (a head shake), so the player knows it was heard.
- **Call-back button:** a new `TouchScreenButton` in `ScreenUI`, shown only while the companion is walking to a spot or waiting. Keyboard: Q (a new `call_back` input action). It emits a new `SignalBus.companion_recalled`; the companion stops and comes back.
- **Back at the player's side:** within the follow distance; from then on a new tap is accepted.
- The companion emits new signals that later steps listen to: `companion_sent`, `companion_tap_ignored`, `companion_arrived`, `companion_stay_finished(full: bool)` (full = it waited the whole time, not called back or out of range), `companion_returned`.
- `send_to_position()` applies the rule (taps); `go_to_position()` just walks, for the path-finding drivers in `test/drive.gd` that chain sends.
- Waypoint queues (more than one spot per send) aren't part of the slice.
- Tests: a second tap while out is ignored; the call-back button and Q during the walk and during the wait; the signals arrive in order.

**3. ✅ `feat/pressure-plate-gate`**: the first puzzle elements.
- **`pressure_plate.tscn`** (`scenes/objects/`): an `Area2D` that's pressed while the Player or the Companion (or later a crate) stands on it, with their feet on the middle of the plate, not just touching its edge. It glows while pressed. Signal `pressed_changed(pressed: bool)`.
- **Sending to the plate:** a tap near a plate (within its `snap_radius`) sends the companion to its centre. Plates are in the `companion_spots` group; other spots can use it later.
- **`gate.tscn`**: a `StaticBody2D` linked to one or more plates (an exported array of plate paths). While a plate is pressed it slides up over `open_time` (1.5 s), and only then can it be walked through. When the plate is released, it shuts at once. Opening and shutting disable and enable its collision and emit `navigation_obstacles_changed`, like the door.
- **Why it opens slowly:** the companion gives up if the player is more than the send range away (step 1), so the plate, the gate and the latch are all close together, and the player can wait right at the gate. If the gate opened at once, any stay time would be enough. The slow opening is what makes the stay time matter: at stay level 0 the gate is fully open for about 0.9 s, at level 1 for about 1.9 s, and walking through the doorway takes about 1.2 s.
- **Latch:** an exported `latch_on_pass` flag: when the player walks through the open gate (in through the doorway on one side, out on the other), it stays open for good. This is saved in the map state (the gate is in `GameMap.PERSISTENT_GROUP`), so it's still open after leaving World and coming back.
- **Closing on someone:** whoever is in the doorway when the gate shuts is pushed back out the way they came. Nobody gets stuck in it, and standing in the doorway doesn't hold it open. (The first plan was for the gate to wait until they were out, but then stepping into the doorway in time would be enough to get through.)
- **The companion and the plate:** a companion sent onto a plate stands on it and presses it while it waits. When its stay ends, it walks off and the plate goes up.
- **`chest.tscn`**: an interactable (through `InteractionManager`, type `"chest"`) that opens once, stays open in the map state and emits `opened`. The treats in it come with step 4.
- **The pen:** `scenes/maps/world/gate_pen.tscn` holds the walls, the gate, the plate and the chest. It's placed in World south-east of the Old Sage, at (1200, 1750).
- Tests (`test/puzzle_test.gd`, headless): the plate and the gate with the player and with the companion; stay level 0 is too short and pushes the player back, level 1 gets through and latches; the chest opens once; the latch and the chest survive a map change; pushing out works both ways.

**4. ✅ `feat/treats`**: the first item.
- `PlayerData.treats: int`, starting at 10 (5 were exactly enough for the training, so one wasted treat left the player stuck), with `add_treats()` and `use_treat()` and a `SignalBus.treats_changed` signal; the chest adds 5 and says so.
- **Give:** a "treat" button, with the count on it, shown when the companion is next to the player (within 120 px, `is_next_to_player()`) and there's at least one treat. Keyboard: T (a new `give_treat` input action). It emits `SignalBus.treat_given`. The companion hops twice (a placeholder until there's art).
- Throwing treats (used by the later stay training in the training plan) isn't part of the slice.
- Tests: the button shows only when the companion is close and there are treats; giving one lowers the count and emits the signal.

**5. ✅ `feat/companion-state`**: a minimal version of `CompanionState` from the nature plan (section 10).
- A new autoload with `mood` (−1 to +1, resting at +0.3 and drifting back to it) and `bond` (0 and up).
- `apply_event(event: StringName)` looks the event up in a table and changes mood and bond. Events in the slice: `treat`, `training_success`, `skill_level_up`, `puzzle_solved`, `recalled`, `stay_too_short`.
- Signals `companion_mood_changed` and `companion_bond_changed`.
- `CompanionState` applies `treat` and `recalled` itself, from `SignalBus.treat_given` and `companion_recalled`. The other events come from the steps where they happen (7 and 8).
- A debug overlay (F3, a new `toggle_debug` input action) that shows mood, bond, treats and the send range; stay level and training progress join it in step 7.
- The nature attributes, needs, feelings and memory come later.
- Tests (`test/companion_state_test.gd`, headless): each event moves mood and bond as the table says; mood stays within −1..+1; the treat and recall signals apply their events; mood drifts back to its resting point; F3 shows the overlay.

**6. ✅ `feat/speech-bubbles`**: the companion talks.
- A bubble above the companion's head (a small panel with a label, following it), shown for a time that depends on the line's length.
- A text bank file, `localization/companion_lines.csv`: one row per line with `key`, `trigger`, `min_mood`, `max_mood`, `min_bond`, `weight`, `cooldown`. The texts themselves are keys in `texts.csv`, in English and Hungarian.
- Triggers in the slice: `sent`, `arrived`, `recalled`, `ignored_tap`, `stay_too_short`, `treat`, `training_progress`, `skill_level_up`, `gate_opened`, `bored` (idle for a while), `sage_hint`. About 2–3 lines each, 25–30 lines in all.
- Choosing: of the lines whose conditions match, one at random by weight; a line said recently is skipped. A chattiness gap (placeholder 4 s) between lines, except for important ones (`skill_level_up`, `gate_opened`).
- No voice yet; the voice decision (AI or babble) is made after a test, outside the slice.
- Tests: the right trigger shows a line from its set; conditions and cooldowns are respected; the bubble follows the companion and disappears.

**7. ✅ `feat/stay-training`**: the first training task.
- `PlayerData.companion_skills` with `stay` and `range` (level and progress), the level tables, and `get_companion_stay_duration()` (training plan, section 8). Only stay gets a task in the slice.
- **The task:** the companion is sent, waits the whole stay (`companion_stay_finished(full = true)`), comes back (`companion_returned`), and the player gives a treat within 5 s of its return. That's one success; five successes raise the stay level.
- The task is a small script that listens to the signals (training plan, section 8: "where the tasks live"), so `companion.gd` stays free of training code.
- **Feedback:** a short toast at the top of the screen ("Stay training 3/5"), the companion's `training_progress` and `skill_level_up` lines, and the `CompanionState` events. The `training_progress` line replaces the treat line said a moment before, so it skips the chattiness gap like the important lines.
- The task is `scripts/training/stay_training.gd`, a node in `main.tscn`. `PlayerData.add_training_progress()` raises the level by itself when the count for the level is reached (`COMPANION_TRAINING_GOALS`, stay: 5, 10, 15, 20). The send range level moved into `companion_skills.range`. Tests that need a fixed wait set `PlayerData.companion_stay_duration_override`.
- The skill tree screen isn't part of the slice.
- Tests: a full task run raises the level; a treat given too late, or a stay cut short by calling back, doesn't count; the new stay duration is used from the next wait.

**8. Putting it together and playtesting**
- ✅ The Sage's hint line (`NPC_OLD_SAGE_GATE_HINT`); after the dialogue the companion answers with a `sage_hint` line (`companion_reply` on the NPC).
- ✅ The companion's `stay_too_short` line when the gate closes in front of the player: `gate_pen.gd` checks, when a full stay on the plate ends, whether the gate shut while the player was still near it, and applies the `CompanionState` event. When the player passes and the latch holds, it says a `gate_opened` line and applies `puzzle_solved`. `stay_too_short` skips the chattiness gap: it comes about 3 s after the line said when the companion is sent.
- ✅ Tuning: the plate-to-gate distance from step 3 holds; level 0 fails and level 1 gets through, in `test/puzzle_test.gd` and in the driver.
- ✅ A driver script, `.claude/skills/run-game/slice_playthrough.gd`, that plays the whole scene: the Sage, fails at level 0, trains five times, succeeds at level 1, the companion follows, opens the chest.
- ✅ A quest, "The old gate" (`scripts/quests/gate_quest.gd`, a node in `main.tscn`), with its text at the top of the screen (`scenes/ui/quest_label.gd`): find the gate (after the Sage), send the companion to the plate and go through, train stay with the x/5 progress (after a try where the gate shut too soon), go through the gate (after the level up), completed. It follows `SignalBus.npc_talked` and `puzzle_event` (`found`, `too_short`, `passed` from `gate_pen.gd`). The screen also has the player's health bar in the top left.
- A playtest on a phone: is it clear what to do, is the training fun or a chore, does the companion feel alive?

### Not in the slice

The skill tree screen, practice and mishaps, the nature attributes and needs, pull and the other skills, combat, the home and saving (everything is lost on restart for now), voice, and the dragon art (the current companion sprite stays as a placeholder).

## Order of work

1. The first playable slice, "the dragon and the gate" (section 10).
2. `feat/combat-basics`: the sword swing, one enemy type, the companion's automatic attack, fainting and waking up.
3. The first small dungeon: a few rooms, a reset, one new element, a simple boss.
4. Story and quests through NPC conversations, once the dialogue system has choices (nature plan).
5. More world puzzles that need training levels, with the companion noticing and remembering them.

Each branch is made from `dev` and merged back with `--no-ff`, as in `CLAUDE.md`.

## Open questions

- **The story:** the setting, the main plot, how many chapters, and how many dungeons.
- **Checkpoints per map:** whether the player wakes at a map checkpoint or always at home after fainting.
- **The home and travel:** does the home move as the world opens up (a tent), or is there a fast way back?
- **Saving:** a save system is needed for everything here; saving happens at home.
- **Money:** gold buys food and treats for the companion. Whether it also buys sword upgrades or furniture for the home is open.
- **Puzzle tools for the player:** is the sword enough, or does the player get one or two tools (a lantern, a slingshot for far switches)?
- **Difficulty settings:** an easy mode, or skippable fights?
- **Enemy variety:** how many kinds per area, and how the companion's nature changes how it fights each one.
