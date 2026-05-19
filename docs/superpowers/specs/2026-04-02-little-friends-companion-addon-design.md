# Little Friends — Minecraft Bedrock Companion Add-on

## Overview

A Bedrock add-on that gives the player three AI companion mobs: an axolotl (builder), a turtle (protector), and a panda (gatherer). Designed for a 5-year-old — companions are autonomous, friendly, and require no complex interaction. They appear magically, help without being asked, and respond to simple single-word chat commands.

## Target

- Minecraft Bedrock 1.26.1202.0+ (GDK build via GDK-Proton on Linux)
- Script API `@minecraft/server` 1.x (bundled with game)
- No network access, no external dependencies

## Companions

### Axie (Axolotl — Builder)

| Property | Value |
|----------|-------|
| Base entity | `minecraft:axolotl` |
| Custom texture | Pastel pink/iridescent sparkle |
| Health | 30 (15 hearts) |
| Role | Builds structures for the player |

**Autonomous behaviors:**
- When sunset approaches (game time ~11000), builds a 5x5 oak shelter near the player: walls, door, 2 windows, torches inside, roof
- When player is near a water gap (3+ blocks wide), builds a bridge in the player's facing direction
- Randomly places flowers near the player every few minutes

**Chat triggers** (single words in chat, no prefix):
- `house` — 5x5 shelter with door, windows, torches
- `wall` — 3-high cobblestone wall encircling the player (8-block radius)
- `bridge` — 10-block bridge in the player's facing direction
- `farm` — 5x5 dirt plot with water channel, plants seeds if in inventory
- `tower` — 3x3 cobblestone tower, 8 blocks tall, with ladder and torch on top

**Building mechanics:**
- Places blocks one-by-one with a short delay (2 ticks per block) — satisfying to watch
- Sparkle particles on each block placed
- Uses blocks from player inventory first; falls back to oak planks/cobblestone (spawned if needed so she's never stuck)
- Announces what it's building via action bar: "Axie is building a house!"

**Personality messages** (action bar, random rotation):
- "La la la... building is fun!"
- "Ooh! I know just what to make!"
- "Ta-da! Do you like it?"
- "I love building with you!"

### Shelly (Turtle — Protector)

| Property | Value |
|----------|-------|
| Base entity | `minecraft:turtle` |
| Custom texture | Shell with backpack texture |
| Health | 60 (30 hearts) |
| Damage | 6 per hit |
| Role | Fights hostile mobs, protects the player |

**Autonomous behaviors:**
- Attacks any hostile mob within 12 blocks of the player
- At night, positions itself between the player and the nearest hostile mob
- Emits a faint glow at night (particle-based nightlight effect)
- After killing a mob, shows heart particles

**Passive traits:**
- Knockback resistance (0.8)
- Higher speed than normal turtle (0.35 vs 0.1)
- Cannot be killed by the player (damage from owner ignored)
- Respawns near player 30 seconds after death

**Warning system:**
- "Shelly hears something scary..." — hostile mob within 20 blocks
- "Stay behind me!" — mob within 8 blocks
- "All safe now!" — after defeating a threat

**Personality messages:**
- "Don't worry, Shelly's here!"
- "Hmm... it's quiet. Too quiet."
- "Yay! Daytime is the best!"
- "I'll stay close tonight."

### Bamboo (Panda — Gatherer)

| Property | Value |
|----------|-------|
| Base entity | `minecraft:panda` |
| Custom texture | Flower crown on head |
| Health | 40 (20 hearts) |
| Role | Gathers resources, brings items, helps farm |

**Autonomous behaviors:**
- Picks up dropped items within 8 blocks and delivers them to the player
- Periodically wanders 15-20 blocks away, returns with a random gift: flowers, seeds, berries, mushrooms, bamboo, sugar cane
- Near mature crops: harvests and replants automatically
- When player hunger is below 10 (5 drumsticks): actively searches for food items nearby

**Passive traits:**
- Occasionally sleeps if the player stands still for 30+ seconds (lies down, snoring particles)
- Panda sneeze animation randomly; drops a bonus item (slimeball, seed, or flower)
- Cannot be killed by the player

**Personality messages:**
- "...yawn... oh! I found something!"
- "Here you go! A present!"
- "Bamboo is sleepy..."
- "Mmm, I smell food nearby!"
- "I'll go look around... be right back!"

## Core Systems

### Spawning (Magical Arrival)

All three companions spawn staggered after the player joins a world:
- **30 seconds:** Axie wanders in from ~20 blocks away with sparkle trail
- **60 seconds:** Shelly arrives from the opposite direction, with a calm glow
- **90 seconds:** Bamboo waddles up, yawning

Each announces arrival via action bar with their intro message.

**Persistence:** Companions are tagged entities saved with the world. On rejoin, if a companion is missing (died, unloaded), it respawns near the player after 10 seconds.

**One set per player:** In multiplayer/LAN, each player gets their own trio (tagged to their player ID).

### Following

- Follow distance: 4-8 blocks (wander casually within this range)
- Teleport threshold: 30 blocks away — instantly teleport near player with particle poof
- When player sprints, companions speed up
- When player stops, companions idle with ambient animations

### Communication

All companion messages use the **action bar** (the text above the hotbar). This is non-intrusive and doesn't require reading chat.

Messages rotate every 15-30 seconds during idle, and trigger immediately for events (building, fighting, gifting).

Format: `[Axie] La la la... building is fun!`

### Particle Effects

| Event | Particle |
|-------|----------|
| Near player (idle) | Occasional heart |
| Building a block | Sparkle/villager_happy |
| Defeating a mob | Heart burst |
| Bringing a gift | Note particles |
| Arriving/teleporting | Cloud poof |
| Shelly nightlight | Small flame particles |
| Sleeping (Bamboo) | Snore-like cloud particles |

### Fear Reactions

All companions briefly scatter (5 blocks) from creeper explosions or TNT, then run back to the player with a scared message ("Eek!" / "That was loud!" / "...Bamboo doesn't like that!").

## Technical Architecture

### Pack Structure

```
little-friends-bp/                    # Behavior Pack
  manifest.json
  pack_icon.png
  entities/
    axie.json                         # Axolotl entity with custom components
    shelly.json                       # Turtle entity with custom components
    bamboo.json                       # Panda entity with custom components
  scripts/
    main.js                           # Entry point — registers event handlers
    companions/
      spawner.js                      # Spawn logic, persistence, respawn
      follower.js                     # Follow/teleport behavior
      communicator.js                 # Action bar messages, personality
    behaviors/
      builder.js                      # Axie's building routines + templates
      protector.js                    # Shelly's combat + warning system
      gatherer.js                     # Bamboo's item pickup + gifting
    templates/
      buildings.js                    # Block-by-block building templates
    utils.js                          # Shared helpers (distance, facing, etc.)

little-friends-rp/                    # Resource Pack
  manifest.json
  pack_icon.png
  textures/
    entity/
      axie.png                        # Custom axolotl texture
      shelly.png                      # Custom turtle texture
      bamboo.png                      # Custom panda texture
```

### Entity Design

Each companion is a custom entity (`little:axie`, `little:shelly`, `little:bamboo`) that extends the vanilla mob's base behaviors. Key components:

- `minecraft:tameable` — auto-tamed to nearest player on spawn
- `minecraft:follow_owner` — base following behavior
- `minecraft:persistent` — won't despawn
- Custom `minecraft:healable` — heals with their favorite food
- `minecraft:damage_sensor` — ignore damage from owner

Script API handles higher-level logic (building, chat parsing, autonomous decisions) while entity JSON handles low-level mob behavior (pathfinding, animations, basic AI).

### Script API Usage

**Entry point** (`main.js`):
- `world.afterEvents.playerJoin` — trigger companion spawn sequence
- `world.beforeEvents.chatSend` — parse single-word building commands
- `system.runInterval` — tick-based updates for autonomous behaviors (every 20 ticks / 1 second)

**Building system** (`builder.js` + `buildings.js`):
- Templates define blocks as relative offset arrays: `[{x, y, z, block}]`
- Builder places one block per 2 ticks using `dimension.setBlockType()`
- Templates are oriented based on player's facing direction

**Combat system** (`protector.js`):
- Query nearby entities with `dimension.getEntities({type: hostile, location, maxDistance: 12})`
- Shelly pathfinds to target and attacks using entity component manipulation
- Warning messages based on distance thresholds

**Gatherer system** (`gatherer.js`):
- Query dropped items with `dimension.getEntities({type: "minecraft:item", maxDistance: 8})`
- Teleport items to player or use pathfinding to "carry" them
- Gift timer: every 2-3 minutes, spawn a random item at Bamboo's location

### Installation

For development, use the development pack folders (auto-reload on file changes):
```
~/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_behavior_packs/little-friends-bp/
~/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/little-friends-rp/
```

For release, copy to the non-development pack folders:
```
.../com.mojang/behavior_packs/little-friends-bp/
.../com.mojang/resource_packs/little-friends-rp/
```

Then activate in-game via world settings (behavior packs + resource packs).

An install script will symlink/copy the packs to the correct location.

## Out of Scope

- Claude API or any network-based AI (Script API has no network access)
- Custom 3D models (using vanilla mob models with custom textures)
- Complex dialogue trees or conversation (action bar messages only)
- Inventory GUI for companions (no custom UI screens)
- Multiple companion instances (one of each per player)

## Success Criteria

- All three companions spawn reliably after joining a world
- Companions follow the player and teleport when too far
- Axie builds at least 3 structure types autonomously and via chat
- Shelly detects and fights hostile mobs
- Bamboo picks up items and brings gifts
- Action bar messages display correctly
- Custom textures render on each companion
- Works on Minecraft Bedrock 1.26.1202.0 via GDK-Proton
