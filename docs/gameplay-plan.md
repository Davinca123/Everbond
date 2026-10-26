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

Buttons appear only when they can be used. The keyboard and mouse work too (bug #3 in `BUGS.md` needs fixing for that).

## Order of work

1. The first world puzzle with the existing skills (send and stay): a pressure plate that opens a gate.
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
