# Haunt Control

**You are the ghost.** Scare every visitor out of your house before they find and destroy your remains.

A small top-down horror prototype built with Godot 4 for the Lila Games Game Designer written test (Question 1). Plain shapes, no art. The point is the loop.

**Play in your browser (one click):** (https://arpit-s-cat.itch.io/hauntcontrol)

Works on desktop (keyboard) and mobile (touch controls, landscape).

---

## The idea

Most horror games make you the victim. Here the visitors are the ones in danger. Each run is a short story: a nervous visitor, two kids, three strangers sheltering from a storm, and finally a priest who fights back. You scare them with your energy, but visitors carry flashlights that drain you, and they are always walking toward your hidden remains.

## Core loop (about 2 to 3 minutes per level)

1. A visitor walks in through the front door.
2. You float around the dark house and scare them (Space). Each scare drains their courage and stuns them.
3. Their flashlight drains **your** energy, so you hide behind walls and strike from the dark.
4. If a visitor finds your remains, they start destroying them. If the red bar fills, you lose.
5. Scare them out of the house to win.

Passing through walls costs energy, so shortcuts compete with scares.

## Levels

| Level | Who comes | What it teaches |
|---|---|---|
| 1. Tutorial | One nervous visitor | Movement, scaring, flashlight, walls, remains |
| 2. Ghost Hunters | Two kids (one brave, one timid) | One kid calling the other over; panic spreading |
| 3. Storm Shelter | Three strangers, rain and lightning | Group search, one scare hitting several people |
| 4. The Exorcist | A priest with double courage | A boss who chases you and fires a holy shockwave |

## Progression: the reward pool

After levels 1 to 3 you choose **one** reward. Abilities you skip are offered again on the next reward screen, and each reward screen adds one new ability.

- **Spectral Surge:** max energy +25%
- **Whisper Mastery:** scares cost 10% less
- **Phase Shift:** walls cost 25% less to cross
- **Banshee Scream (E):** once per level, visitors inside lose 10% courage and walk slower. Your energy refills 25% slower for the rest of that level.
- **Soul Shift (Q):** once per level, your remains jump far away. Your energy always refills 10% slower. Using both Scream and Soul Shift in one level makes it 40% slower.

On the priest level you also get a **Dodge** (Shift / X / DODGE button). Dodge his shockwave with good timing, then scare him within 1 second for a counter hit worth 35% of his courage.

## Controls

**Desktop**

| Key | Action |
|---|---|
| Arrow keys | Move |
| Space | Scare |
| E | Scream (once unlocked) |
| Q | Soul Shift (once unlocked) |
| Shift or X | Dodge (priest level) |
| R | Restart level |
| M | Main menu |
| Enter | Next level (after a win) |
| 1 to 4 | Jump to a level |
| 0 | Reset progress |

**Mobile:** drag on the left half of the screen to move (floating joystick). Use the buttons on the right for Scare, Scream, Soul Shift and Dodge.

## Settings

The main menu has a sound slider and a Lighting option (Auto, Full, Medium, Lite). Lite and Medium exist because some low-memory phones could not draw the flashlights with wall shadows. The game picks automatically on low-RAM devices.

## Run it yourself

1. Install **Godot 4.x** (the standard version, not .NET).
2. Open Godot, click **Import**, and choose `project.godot` from this repo.
3. Press **F5** to play.

The whole game lives in one script, `main.gd`, on the root node of `main.tscn`. Level data (visitors, courage, speeds, dialogue) is at the top of the script, and tuning values are constants near the top.

## How AI was used

AI was used heavily and is disclosed here on purpose.

- **Where AI helped:** writing and revising the GDScript, suggesting early concept options, and iterating on balance and bug fixes during playtesting.
- **What I decided:** the game concept (playing the ghost), the visitor scenarios and their dialogue direction, the reward-pool design, the energy trade-offs, the priest boss behaviour, the tutorial approach, and every tuning change after testing.
- **AI in the game itself:** none in this prototype. Visitors use simple rule-based behaviour.

`FILL-IN: add 2 or 3 specific examples of things you tested and changed yourself, for example a number you tuned, or a rule you rejected.`

## Assets and credits

All visuals are drawn in code with plain shapes.

| File | Used for | Source | Licence |
|---|---|---|---|
| `sfx/ambience.ogg` | Background ambience | `FILL-IN` | `FILL-IN` |
| `sfx/scare.mp3` | Scare sound | `FILL-IN` | `FILL-IN` |
| `sfx/flee.wav` | Visitor running away | `FILL-IN` | `FILL-IN` |
| `sfx/scream.*` (optional) | Banshee Scream | `FILL-IN` | `FILL-IN` |
| `sfx/shockwave.*` (optional) | Priest shockwave | `FILL-IN` | `FILL-IN` |
| `sfx/dodge.*` (optional) | Dodge | `FILL-IN` | `FILL-IN` |

## Built with

Godot 4.x, GDScript, exported to HTML5 (web) and hosted on itch.io.
