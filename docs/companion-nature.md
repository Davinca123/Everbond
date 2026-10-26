# Plan: the companion's nature

The companion is an independent individual, not a tool. It has a personality (nature attributes), a mood that changes all the time, and needs (health, food, drink, cleanness, fatigue). Together they decide how it behaves: whether it obeys, what it says, what it does when nobody asks it anything.

It talks: to the player and to NPCs, with a speech bubble over its head and a voice. The player can answer. Conversations build the relationship, and in some of them the companion teaches the player.

The goal is a companion that feels alive: a lot of random activity and talk, triggered by its nature, its mood and the situation.

## Tone: cute and joyful

The baseline of the whole game is cuteness and joy, and the companion is part of it:

- **It stays cute,** in how it looks and how it behaves, through every form (section 8). Later forms can look cooler, but never lose the cuteness.
- **It's a fundamentally positive character.** It has negative attributes too, because they make it an individual, but they come out in a cute, harmless way:
  - rude → cheeky, sassy ("Ugh, *fine*."), never hurtful,
  - selfish → sneaks the last cookie, then looks innocent,
  - lazy → flops over dramatically, naps in silly places,
  - stubborn → sits down and refuses to budge, with a pout,
  - pessimist → gloomy little sighs, then cheers up when it works,
  - touchy → sulks with its back turned, easily won back with a treat or a kind word,
  - fears → hides behind the player, peeks out.
- **Its mood rests on the happy side.** Even a pessimist companion's resting mood is above neutral; bad moods are short dips, not a state it lives in.
- **Nothing is cruel.** Getting hurt is a bonk and a little bandage, not blood. Telling it off is gentle. Neglect makes it sad and needy, never sick or lost.

Every line in the text bank and every animation should pass this test: is it cute?

Related: [companion skills and training](companion-training-plan.md). Training teaches the commands, practice builds dexterity and attention, and this document decides whether the companion feels like doing what it's asked.

## Where things stand

- `PlayerData` has `companion_name` ("Lélektárs"), `companion_obedience` and `companion_unlocked_skills`. None of them are used yet.
- `SignalBus` has `companion_obedience_changed` and `companion_leveled_up(new_form)`, unused. The second suggests the companion may change form; see [open questions](#open-questions).
- Dialogue: `dialogue_box.gd` shows a list of lines from one speaker in a box at the bottom of the screen (`SignalBus.dialogue_started(speaker_name, lines)`). There are no answer choices, no speech bubbles and no voice. Bug #3 in `BUGS.md`: the dialogue can't be advanced on PC.
- NPCs (`npc.gd`) have a fixed list of `dialogue_lines` and start a dialogue when the player presses the interaction button.
- There is no combat, no day/night cycle and no save system yet.

## 1. Species, name and nature attributes

**Species:** the companion is a cute dragon. Later there may be more creatures, one picked at random at the start of a game. Each new species multiplies the work (its own sprites for every form, action and gesture), so:

- The first version has only the dragon.
- The code treats the species as data from the start: a `CompanionSpecies` resource with its sprites per form, its sounds, and any species-specific touches. Adding a species then means adding assets, not changing code.
- All species share the same skills, training tree, needs and nature system. A species only changes the look, the voice and small flavour (a dragon's sneeze is a puff of smoke; it dislikes water a little more). Species-only skills would multiply the tree, so they're left out unless one is really worth it.

**Name:** the player types a name, or takes a random one from a list. The names on the list store their Hungarian suffixed forms (section 4). For a typed name the suffixes are worked out by rule (vowel harmony and the last letter: *Pötyivel*, *Lánggal*, *Bogyóval*), with a way to check it in the naming screen.

**Nature:** picked at random at the start of a game, within the limits in the [tone section](#tone-cute-and-joyful): the positive side is always the stronger one.

Each attribute is a value from 0 to 1: how strongly the companion has it. Some come in opposite pairs, which are stored as a single axis so they can't both be high:

| Axis | 0 | 1 |
|---|---|---|
| kindness | rude | kind |
| patience | impatient | patient |
| outlook | pessimist | optimist |
| generosity | selfish | generous |
| energy | lazy | eager |

Others stand alone, since their opposite is just "not much of it":

- **funny:** jokes, teasing, silly actions.
- **sarcastic:** dry or mocking comments. Can go with kind (friendly teasing) or with rude (biting).
- **curious:** sniffs around, gets distracted, finds things.
- **persistent:** keeps trying after a failure instead of giving up.
- **stubborn:** sticks to its own idea, refuses commands it doesn't like.
- **touchy:** takes criticism and failure hard; its mood swings further.

**Fears:** a list of things the companion is afraid of, each with a strength: water, the dark, heights, thunder, certain animals or NPCs. Near a feared thing, its mood drops, it may refuse to go closer, and it says so.

**Likes and dislikes:** foods, treats, places, weather, NPCs, activities. These are what make a treat "a favourite" or an NPC "a friend" (section 6).

**What the attributes do:**
- They set the mood's resting point and how far events move it (section 2).
- They change the chance of each behaviour: refusing (stubborn), wandering off (curious), giving up (low persistence), napping (lazy).
- They tag the lines it says (section 4): a rude companion picks rude lines, a funny one picks jokes.
- They change combat behaviour, once there's combat: a persistent, eager companion is more determined; a fearful one hangs back.

**Do the attributes change?** Yes, a little. They're set at the start and drift slowly with how the player treats the companion. A companion that's often praised slowly gets kinder; one that's often told off gets touchier or cheekier. Changes are small and slow, so its character stays recognisable. A form change (section 8) can shift them a little too. The positive side always stays the stronger one: drift and form changes can't push the companion past a limit toward the negative end.

## 2. Mood

Mood is how the companion feels right now. One value from −1 (miserable) to +1 (very happy), drawn back toward a resting point over time.

**Resting point:** set by the nature attributes (an optimist rests higher than a pessimist, but both above neutral) and lowered by unmet needs (section 3): a hungry, tired, dirty companion rests lower.

**Events that move it**, with placeholder sizes:

| Event | Change |
|---|---|
| a treat (a favourite treat counts more) | + |
| praise from the player | + (more for a touchy companion) |
| praise from an NPC | + |
| a cozy place (a fire, a warm house, a soft bed) | slowly + while there |
| sleeping | + when it wakes up rested |
| a nice chat with the player or a liked NPC | + |
| a success, especially a hard one | + |
| a failed task or a mishap | − (more for a touchy or pessimist companion, less for a persistent one) |
| getting hurt | − |
| being told off | − (much more for a touchy companion) |
| wet fur (rain, water) | − while wet |
| being near something it fears | − while near |
| exhaustion, hunger, thirst | − through the resting point |
| a refused command that the player insists on | − |

**Short feelings:** besides the mood value, a few short-lived states that come from events and end by themselves: scared, excited, bored, sulking, proud. They pick lines and animations ("sulking" after a scolding: it turns its back for a while). They're optional; mood alone is enough to start.

**What mood does:**
- Mishap chances (practice, in the training plan) go up in a bad mood.
- The chance to refuse a command goes up in a bad mood (section 5).
- It picks the tone of what the companion says.
- It shows: an expression or posture, and an icon in the companion's panel.

## 3. Needs and health

Stats, each from 0 to 100:

| Stat | Goes down when | Goes up when | When it's low |
|---|---|---|---|
| health | hurt in a mishap or in combat | resting, healing items, time | slower, more mishaps; at 0 it faints (see below) |
| food | over time, faster when active | eating (treats, meals) | mood resting point drops; asks for food |
| drink | over time, faster in heat and when active | drinking (water, a bowl) | as food, but faster |
| cleanness | mud, water, rolling in things | washing, a bath, grooming | mood drops; NPCs may comment |
| fatigue (energy) | activity, long walks, training | sleeping, resting | slower, refuses more, yawns, may nap on the spot |

**Mood** is the sixth stat, described in section 2.

**Wet fur** is a short state, not a stat: it dries over time, faster near a fire, and makes the companion dirtier if it then rolls in dirt.

**Fainting at 0 health:** no death. It faints (cutely: dizzy stars, a little "ow"), the player carries it home or to a healer, and its mood drops. This keeps the bond central without a game-over.

**Pacing:** needs should drop slowly enough to be a light care routine, not a chore. A long play session might need one meal and one nap.

## 4. Talking

The companion speaks in a speech bubble over its head, with a voice.

**Voice:** two options, to be decided after a test (see [open questions](#open-questions)):

- **AI voice, generated ahead of time:** a text-to-speech service with a designed voice (not a cloned real person's voice) generates an audio file for every line, in English and Hungarian, as part of the build. Lines are voiced fully and in the companion's own voice. Things to check first: whether the voice sounds cute and consistent across thousands of lines and emotions, how good the Hungarian is, the service's licence for commercial use, the cost, the store rules (Steam asks for AI-generated content to be disclosed), and the download size (thousands of lines × 2 languages × each form's voice). Lines with inserted words (names, items) can't be pre-generated unless they're split into fixed pieces.
- **Babble:** a voice made of short sounds (chirps, purrs, a babble), picked by the line's mood and length, as in Animal Crossing or Banjo-Kazooie. Cheap, small, works in every language, and very cute.

They can also be mixed: babble for chatter and free-time lines, the AI voice for conversations with the player and story moments.

**Generating voice and text while the game runs:** possible, but not as the base. Details in [section 4a](#4a-generating-voice-and-text-while-the-game-runs).

**Forms without re-recording:** whichever voice is used, each form's tone can come from the same audio, played through Godot's audio effects (pitch shift, a little EQ or reverb on the companion's bus). Only a voice that's really different needs its own files.

**Languages:** the language can be changed in the settings. English and Hungarian at first. Every line, menu and NPC text goes through Godot's translation system (`tr()` and translation CSV files) from the start, with keys rather than English text in the code. Hungarian needs care with inserted words: suffixes depend on the word (*a kutyával*, *a macskával*, but *Lélektárssal*), so names and items inserted into sentences need their suffixed forms stored, or the sentence written so the word doesn't need a suffix.

**Text bank:** every line is a record with tags that say when it may be said:

```
id:        greet_morning_grumpy_03
text:      "Morning. Don't talk to me before breakfast."
trigger:   wake_up
needs:     mood < -0.2, food < 40
nature:    kindness < 0.5 OR sarcastic > 0.5
weight:    1.0
cooldown:  1 day
```

- **trigger:** the situation (waking up, a failed pull, a treat, entering a map, seeing an NPC, a long silence, rain starts, …).
- **conditions:** mood, needs, nature, relationship level, location, time of day, what has happened before (memory).
- **choosing:** of the lines whose conditions match, one is picked at random by weight. Lines said recently are skipped (cooldowns, no repeats).
- **storage:** a CSV or JSON file, not scenes, so the bank can grow to thousands of lines and be translated with Godot's translation files.

**Volume:** a companion that talks a lot needs thousands of lines per language to avoid repeating itself. Ways to get there:
- **Drafting with AI while making the game:** a language model drafts lines in bulk for each trigger, mood and nature combination, in English and Hungarian, already in the text bank's format. A person reads every line, keeps the cute ones and fixes the rest. This gives the volume of generated text without its risks at runtime.
- **Templates:** a line with slots, such as "Ooh, {item}! Can I have it?", covers many situations with one line. Slots are kept to words whose Hungarian suffixes are stored (see Languages).
- **Small pieces:** short reactions ("Yay!", a giggle, a huff) that can be said often without feeling repeated, mixed with longer lines that have long cooldowns.
- **Memory and context:** lines that refer to memories and the current place feel fresh even when the bank is smaller.

**How often it talks:** a "chattiness" budget, so it never talks over itself or over a dialogue, and important lines come before small talk. A setting lets the player turn chatter down.

**Memory:** a log of notable events (the first time it got hurt, a scolding, a friend NPC, a big success). Lines can refer back to them ("Remember the river? Let's not do that again."). This is cheap and makes the companion feel aware.

## 4a. Generating voice and text while the game runs

**Voice generated live (text-to-speech at runtime):**
- **From an online service:** good quality, every language, any tone. But the game then needs an internet connection to talk, every line costs money for as long as people play (for every player), there's a short delay before each line, and if the service changes or shuts down, the companion goes silent.
- **On the device:** small open-source speech models run offline, and some can speak Hungarian. But a cute, expressive voice with emotions is still hard to get from them, the model adds its own size to the download (often comparable to a large bank of compressed lines), and it costs battery and CPU on phones. Godot's built-in text-to-speech uses the system's voice, which is robotic and different on every device.
- **What it would save:** storing each line in two languages. The form tones don't need it (pitch shift, above).

**Text generated live (a language model writing the lines):**
- **What it's good at:** endless small talk that reacts to everything (the nature, the mood, the memory log, the place, what just happened), in any language, without writing thousands of lines.
- **How it fits a fixed story:** only as a layer on top. Story conversations, relationship steps, clues and teaching lines stay written, because they must be exact. The model writes only free-time chatter and small talk, and is given the facts it may use (the current quest, known places, memories) so it doesn't invent clues that lead the player astray.
- **Problems:** it can say things that aren't cute, are wrong, or are unsuitable for children, so it needs strict instructions and filtering. It has the same online costs, delay and dependency as the voice. Stores have rules for live-generated content (Steam asks how it's kept safe). The player's answers are picked from a list, and each answer's effect on the bond must be reliable, so generated answers would also need checking.

**Recommendation:** build the game on the written text bank, with pre-generated voice or babble. It works offline, costs nothing per player, and stays cute and correct. A live-generated chatter layer can be tried later as an optional, online-only extra, with the written bank as the fallback. The text bank's tags (trigger, conditions) are exactly what such a layer would need as input, so nothing is wasted.

## 5. Behaviour: commands and free time

**Responding to a command:** even a fully learned and practised command can be refused. Each command rolls:

- **obey:** does it, maybe with a comment.
- **grudging:** does it slowly, with a complaint.
- **delay:** "In a minute." Does it a few seconds later.
- **refuse:** doesn't do it, and says why (or just ignores the player, if rude).

The chance to refuse goes up with stubbornness, a bad mood, fatigue and unmet needs, and down with the relationship level (section 7) and how well the command is trained. A refused command can be asked again; asking again pushes the mood down a little but may get it done. A refusal is always cute (it sits down and pouts, or yawns and looks away), never mean.

**Fairness:** refusals must not lock the player out of a puzzle or a fight. The refusal chance is capped, and each refusal in a row makes the next one less likely, so a second or third try always works eventually. Story-critical moments can skip the roll.

**Free time:** when nothing is asked of it, the companion picks an activity from what fits its nature, mood, needs and surroundings:

- chase a butterfly (curious, good mood),
- sniff around and maybe find an item (curious),
- nap (lazy, tired),
- sulk (bad mood, touchy),
- play, roll in the grass (eager, good mood),
- go to a liked NPC and chat with them (section 6),
- drink from a pond (thirsty), look for food (hungry),
- stay close to the player (fearful, scared).

It stays within the follow distance and comes back when the player moves on. The distractions in the training plan's practice section are this same system, triggered during a stay.

## 6. Conversations

**With the player:** either one can start a conversation, the player with a "talk" button, the companion when something prompts it (a long quiet moment, a place, a memory, a need). The player answers by picking from a few responses.

- **Small talk:** chats about the place, the weather, an NPC, the day.
- **Relationship:** some conversations are steps in the relationship, unlocked at certain levels. Answers can raise or lower it.
- **Teaching the player:** the companion explains things: a game mechanic, how to read a puzzle, the world's lore, a hint. This makes it a natural tutorial, and the player's answers can show whether they understood.
- **The player's answers shape the companion:** praise, teasing, kindness or harshness nudge its mood now and its nature over time (section 1). The player is a silent hero: they never speak aloud, they only pick answers.
- **Telling off happens only here:** the player can answer angrily or rudely. There's no separate action for it.
- **Conflict and making up:** an argument lowers the mood and the bond for now, but a reconciliation afterwards (an apology, a treat, a heart-to-heart talk, coming back to it later) raises the bond more than kind chit-chat would. Conflicts stay cute: a pout, a huff, a short sulk, never real hurt. A touchy companion sulks longer, a kind one forgives sooner.

**With NPCs:**
- Each NPC has a relationship with the companion: liked, neutral, disliked. Liked NPCs draw it over for a random chat.
- A chat can give it a small loot (a treat, a coin, an item), or a clue about the current task, which it passes on to the player.
- NPCs react to its nature: a rude companion may annoy a shopkeeper, a funny one may cheer someone up and unlock a reward.
- The player sees NPC chats as bubbles over both heads, without stopping the game. Only conversations with the player use the dialogue box with choices.

**Needed in the dialogue system:** response choices, speech bubbles above a character's head, lines from the text bank instead of fixed lists in the NPC, and conditions and effects on lines (mood, relationship, items). Bug #3 (no way to advance on PC) should be fixed first. An existing format could help, such as Dialogic or Ink, rather than building one from scratch.

## 7. Relationship (bond)

The bond between the player and the companion is one of the most important stats in the game. It's a stat of its own, from 0 up, and almost everything here depends on it:

- **Raised by:** training (the training plan says training builds the bond), conversations, treats, care (feeding, washing, letting it sleep), praise, shared successes.
- **Lowered by:** scolding, neglect (needs left low), insisting on refused commands.
- **What it does:** fewer refusals, warmer lines, relationship conversations unlock, skills unlock (a skill tree requirement can be a bond level), and form changes (section 8).
- **Thresholds only conflicts can pass:** at certain bond levels, a cap that kind chit-chat, treats and care can't push past. Only a conflict that ends in a reconciliation lifts the bond over it, like a real friendship that grows through a falling-out. The game makes sure such a conflict comes up (a story moment, a refusal at a bad time, an argument in conversation) when the bond is stuck at a threshold.
- **It shows:** the bond level is visible on the companion's screen, for example as a heart that fills, and big steps are celebrated with a short moment.

The bond replaces `PlayerData.companion_obedience`, which is dropped.

## 8. Forms

The companion changes form at certain points of its training and advancement. `SignalBus.companion_leveled_up(new_form)` already exists for this.

- **How many:** 3 forms for now (the starting one and two more).
- **When:** at milestones, such as a bond level together with certain skill levels. The exact points depend on the story, which isn't written yet.
- **Look:** each form stays cute; later forms can look cooler (bigger, a new colour, a small accessory, glowing details).
- **Nature:** a form change can shift the nature attributes a little, within the limits in section 1, so it grows up a bit but stays itself.
- **Voice:** each form's voice is a little different (a little deeper or more confident), whichever voice option is chosen.
- **Skills change with the form:** a new form can change how a skill looks and works, not only how strong it is. For example, carry is learned in form 2, and in form 3 the companion is big enough to swallow what it carries and spit it out (training plan, section 5).
- **A moment:** the change is a small celebration, with a conversation where the companion talks about how it feels.

## 9. Small bonds

Small, cute ways to show and build the relationship:

- **Pet:** a button (or a tap and hold on the companion) to pet or hug it. It raises the bond a little, with a cute reaction that depends on its mood and nature. A cooldown stops it from being spammed for bond.
- **Gifts:** at a high bond, the companion sometimes brings the player something it found: a flower, a shiny stone, now and then something useful. What it brings fits its nature (a selfish one brings half a cookie, after eating the other half).
- **Scrapbook:** a journal of shared memories, made from the memory log (section 4): the first treat, the first fall-out and making up, the form changes, friends among the NPCs. Each entry has a little picture and a line in the companion's words. It shows the bond's history.
- **Its own corner:** a bed or nook in the player's home (gameplay plan, section 7), which the player can decorate. Being there gives the "cozy" mood boost, and it naps there when tired.

## 10. Data

A new autoload, `CompanionState`, separate from `PlayerData`, since it's a lot of data:

- `nature: Dictionary` (attribute → 0..1), `fears`, `likes`, `dislikes`
- `mood: float`, `feelings: Dictionary` (short state → time left)
- `health`, `food`, `drink`, `cleanness`, `energy`, `wet: float`
- `species: CompanionSpecies`, `companion_name` and its suffixed forms
- `bond: float`, `form: int`, `npc_relations: Dictionary`
- `memory: Array` (notable events)
- functions such as `apply_event(event: StringName)`, which looks up the event's effects (mood, needs, bond) in a table and emits `SignalBus` signals (`companion_mood_changed`, `companion_need_changed`, …).

`companion.gd` gets a "brain" that, every second or so, checks needs and feelings and picks a free-time activity or a line to say. The command refusal roll sits where a command comes in.

**How the brain decides: scores and chances, not a neural network.** Each option (an activity, a line, a response to a command) gets a score from simple formulas over the nature, mood, needs, bond and situation. For example:

```
chase_butterfly = curious * 0.6 + max(mood, 0) * 0.3 + energy_ratio * 0.2 - (busy ? 1 : 0)
```

The brain then picks among the best-scoring options at random, weighted by score, so the same companion in the same situation usually does the same kind of thing, but not always. This is utility AI, the approach games like The Sims use for their characters' free will.

A neural network was considered and isn't used:
- **It needs training data:** examples of the right behaviour in thousands of situations. Someone would have to write them, which is more work than writing the formulas.
- **It can't be tuned or explained:** if the companion naps too often, a formula shows why and one number fixes it. A network has to be retrained, and it's hard to tell why it did something.
- **It can't guarantee the rules:** the cuteness limits, the caps on refusals and the bond thresholds have to hold every time. A formula can enforce them; a network only learns them approximately.
- **It doesn't write lines:** a network over game events could pick a line from the bank, which the scores already do. Writing new lines is what the optional live text layer is for (section 4a).

Formulas with chances give the same "individual" feel, because the nature attributes are part of every score, so two companions with different natures behave differently in the same situation. The weights live in a data table, so they can be tuned in playtesting without changing code.

Training and practice data (in the training plan) stay in `PlayerData` for now, but could move here.

## Order of work

1. `feat/localization`: the translation setup and a language setting (English, Hungarian), before many texts exist.
2. `feat/companion-state`: the `CompanionState` autoload, needs over time, mood and events, a debug overlay to see them.
3. `feat/speech-bubbles`: the bubble above the companion and the text bank with triggers and conditions, starting with a handful of lines.
4. `feat/companion-free-time`: the brain and the first activities (sniff, nap, butterfly).
5. `feat/command-refusal`: the obey/grudging/delay/refuse roll.
6. `feat/dialogue-choices`: response selection in the dialogue box (after bug #3).
7. `feat/companion-npc-chat`: NPC relations, random chats, loot and clues.
8. Care actions (feed, give water, wash, bed, its own corner) as the items and places for them appear, and petting, gifts and the scrapbook.
9. Forms, when the first new form is drawn.

Each branch is made from `dev` and merged back with `--no-ff`, as in `CLAUDE.md`.

## Open questions

- **Voice:** test an AI voice with 20–30 lines in both languages and a few moods. If it's cute and consistent and the licence fits, use it; otherwise babble (section 4). A live-generated layer is a later, optional experiment (section 4a).
- **Forms:** which milestones, and what each looks like; this waits for the story.
- **More species:** whether to add them at all, and when. Each one is a full set of sprites for three forms.
- **Writing tool:** how lines are drafted, reviewed and imported into the text bank (a spreadsheet, or a small editor tool in Godot).
- **Bond thresholds:** at which levels, and what kinds of conflicts can unlock them.
- **Time:** is there a day/night cycle? Sleep, "good morning" lines and fatigue fit one well.
- **Combat:** how does the companion take part, and how much does its nature change that?
- **How much randomness is fun?** Refusals and wandering off are charming until they block the player; the caps in section 5 need playtesting.
- **Saving:** all of this is lost on restart until a save system exists.
