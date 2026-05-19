# Little Friends Companion Add-on Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Minecraft Bedrock add-on with three companion mobs (axolotl builder, turtle protector, panda gatherer) that autonomously help a 5-year-old player.

**Architecture:** Behavior pack with entity JSON definitions + Script API (`@minecraft/server` 2.6.0) for higher-level logic. Resource pack with custom textures and client entity definitions. Entities use vanilla mob geometry/animations with custom textures. Script API handles spawning, chat parsing, building, combat targeting, and item gathering.

**Tech Stack:** Minecraft Bedrock Script API 2.6.0, Entity JSON (format_version 1.21.0), Resource Pack (format_version 2), JavaScript (ES modules)

**Important:** Requires "Beta APIs" enabled in world settings for `chatSend` events. The install script will note this.

**com.mojang path:**
```
~/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/
```

---

## File Structure

```
little-friends-bp/                        # Behavior Pack
  manifest.json                           # Pack metadata, script module, @minecraft/server 2.6.0 dep
  pack_icon.png                           # 64x64 pack icon
  entities/
    axie.json                             # Axolotl companion entity definition
    shelly.json                           # Turtle companion entity definition
    bamboo.json                           # Panda companion entity definition
  scripts/
    main.js                               # Entry point — event subscriptions, tick loop
    companions/
      spawner.js                          # Spawn, persist, respawn companions
      follower.js                         # Teleport logic (follow_owner is in entity JSON)
      communicator.js                     # Action bar messages, personality lines
    behaviors/
      builder.js                          # Axie building logic + chat trigger handler
      protector.js                        # Shelly combat + warning system
      gatherer.js                         # Bamboo item pickup + gifting
    templates/
      buildings.js                        # Block-by-block building templates (house, wall, etc.)
    utils.js                              # Distance calc, facing direction, random helpers

little-friends-rp/                        # Resource Pack
  manifest.json                           # Pack metadata
  pack_icon.png                           # 64x64 pack icon
  entity/
    axie.entity.json                      # Client entity: geometry, texture, render controller
    shelly.entity.json                    # Client entity for turtle
    bamboo.entity.json                    # Client entity for panda
  render_controllers/
    little_friends.render_controllers.json  # Custom render controllers for all 3
  textures/
    entity/
      axie/axie.png                       # Custom axolotl texture (pastel pink sparkle)
      shelly/shelly.png                   # Custom turtle texture (backpack on shell)
      bamboo/bamboo.png                   # Custom panda texture (flower crown)

scripts/
  install-addon.sh                        # Copies/symlinks packs to com.mojang dev folders
```

---

### Task 1: Behavior Pack Scaffold — manifest.json and pack icon

**Files:**
- Create: `little-friends-bp/manifest.json`
- Create: `little-friends-bp/pack_icon.png`

- [ ] **Step 1: Create behavior pack manifest**

Create `little-friends-bp/manifest.json`:

```json
{
    "format_version": 2,
    "header": {
        "name": "Little Friends",
        "description": "Three adorable companion mobs that help you explore, build, and survive!",
        "uuid": "a1b2c3d4-1111-2222-3333-aabbccddeeff",
        "version": [1, 0, 0],
        "min_engine_version": [1, 21, 0]
    },
    "modules": [
        {
            "description": "Little Friends behavior data",
            "type": "data",
            "uuid": "a1b2c3d4-4444-5555-6666-aabbccddeeff",
            "version": [1, 0, 0]
        },
        {
            "description": "Little Friends scripts",
            "type": "script",
            "language": "javascript",
            "uuid": "a1b2c3d4-7777-8888-9999-aabbccddeeff",
            "version": [1, 0, 0],
            "entry": "scripts/main.js"
        }
    ],
    "dependencies": [
        {
            "uuid": "b2c3d4e5-1111-2222-3333-ffeeddccbbaa",
            "version": [1, 0, 0]
        },
        {
            "module_name": "@minecraft/server",
            "version": "2.6.0"
        }
    ]
}
```

Note: The first dependency UUID must match the resource pack's header UUID.

- [ ] **Step 2: Create a simple pack icon**

Create a 64x64 PNG `little-friends-bp/pack_icon.png`. Generate a simple icon with three colored circles (pink, green, brown) representing the three companions. Use ImageMagick:

```bash
convert -size 64x64 xc:'#2d1b4e' \
  -fill '#ff9ec5' -draw 'circle 16,24 16,34' \
  -fill '#5cb85c' -draw 'circle 32,36 32,46' \
  -fill '#8B6914' -draw 'circle 48,24 48,34' \
  -fill white -font Helvetica -pointsize 10 -gravity south -annotate +0+4 'Friends' \
  little-friends-bp/pack_icon.png
```

If ImageMagick isn't available, create a minimal valid 64x64 PNG programmatically with Python.

- [ ] **Step 3: Commit**

```bash
git add little-friends-bp/manifest.json little-friends-bp/pack_icon.png
git commit -m "feat: scaffold behavior pack with manifest and icon"
```

---

### Task 2: Resource Pack Scaffold — manifest.json and pack icon

**Files:**
- Create: `little-friends-rp/manifest.json`
- Create: `little-friends-rp/pack_icon.png`

- [ ] **Step 1: Create resource pack manifest**

Create `little-friends-rp/manifest.json`:

```json
{
    "format_version": 2,
    "header": {
        "name": "Little Friends Resources",
        "description": "Textures and models for Little Friends companions",
        "uuid": "b2c3d4e5-1111-2222-3333-ffeeddccbbaa",
        "version": [1, 0, 0],
        "min_engine_version": [1, 21, 0]
    },
    "modules": [
        {
            "description": "Little Friends resources",
            "type": "resources",
            "uuid": "b2c3d4e5-4444-5555-6666-ffeeddccbbaa",
            "version": [1, 0, 0]
        }
    ]
}
```

The header UUID here (`b2c3d4e5-1111-2222-3333-ffeeddccbbaa`) must match the BP's dependency UUID.

- [ ] **Step 2: Copy pack icon**

```bash
cp little-friends-bp/pack_icon.png little-friends-rp/pack_icon.png
```

- [ ] **Step 3: Commit**

```bash
git add little-friends-rp/manifest.json little-friends-rp/pack_icon.png
git commit -m "feat: scaffold resource pack with manifest and icon"
```

---

### Task 3: Entity JSON — Axie (Axolotl Companion)

**Files:**
- Create: `little-friends-bp/entities/axie.json`

- [ ] **Step 1: Create Axie entity definition**

Create `little-friends-bp/entities/axie.json`:

```json
{
    "format_version": "1.21.0",
    "minecraft:entity": {
        "description": {
            "identifier": "little:axie",
            "is_spawnable": false,
            "is_summonable": true,
            "is_experimental": false
        },
        "component_groups": {
            "little:tamed": {
                "minecraft:is_tamed": {},
                "minecraft:behavior.follow_owner": {
                    "priority": 2,
                    "speed_multiplier": 1.5,
                    "start_distance": 8,
                    "stop_distance": 3,
                    "can_teleport": true
                }
            }
        },
        "components": {
            "minecraft:type_family": {
                "family": ["axolotl", "mob", "animal"]
            },
            "minecraft:collision_box": {
                "width": 0.75,
                "height": 0.42
            },
            "minecraft:health": {
                "value": 30,
                "max": 30
            },
            "minecraft:movement": {
                "value": 0.2
            },
            "minecraft:underwater_movement": {
                "value": 0.2
            },
            "minecraft:navigation.walk": {
                "can_path_over_water": true,
                "avoid_water": false,
                "can_float": true
            },
            "minecraft:movement.amphibious": {
                "max_turn": 15.0
            },
            "minecraft:physics": {},
            "minecraft:pushable": {
                "is_pushable": true,
                "is_pushable_by_piston": true
            },
            "minecraft:persistent": {},
            "minecraft:breathable": {
                "total_supply": 15,
                "suffocate_time": 0,
                "breathes_water": true,
                "breathes_air": true
            },
            "minecraft:damage_sensor": {
                "triggers": [
                    {
                        "cause": "all",
                        "deals_damage": true
                    }
                ]
            },
            "minecraft:knockback_resistance": {
                "value": 0.3
            },
            "minecraft:behavior.random_stroll": {
                "priority": 8,
                "speed_multiplier": 0.8,
                "xz_dist": 4,
                "y_dist": 2
            },
            "minecraft:behavior.look_at_player": {
                "priority": 9,
                "look_distance": 8,
                "probability": 0.1
            },
            "minecraft:behavior.float": {
                "priority": 0
            }
        },
        "events": {
            "little:tame": {
                "add": {
                    "component_groups": ["little:tamed"]
                }
            }
        }
    }
}
```

Key design choices:
- `is_spawnable: false` — Script API spawns them, not spawn eggs
- `is_summonable: true` — allows `/summon` for testing
- Uses `movement.amphibious` so axolotl works on land and water
- `follow_owner` is in a component group activated by the `little:tame` event (triggered by script after spawn)
- Health: 30 (15 hearts, tanky enough to survive)

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/entities/axie.json
git commit -m "feat: add Axie (axolotl) entity definition"
```

---

### Task 4: Entity JSON — Shelly (Turtle Companion)

**Files:**
- Create: `little-friends-bp/entities/shelly.json`

- [ ] **Step 1: Create Shelly entity definition**

Create `little-friends-bp/entities/shelly.json`:

```json
{
    "format_version": "1.21.0",
    "minecraft:entity": {
        "description": {
            "identifier": "little:shelly",
            "is_spawnable": false,
            "is_summonable": true,
            "is_experimental": false
        },
        "component_groups": {
            "little:tamed": {
                "minecraft:is_tamed": {},
                "minecraft:behavior.follow_owner": {
                    "priority": 2,
                    "speed_multiplier": 1.5,
                    "start_distance": 8,
                    "stop_distance": 3,
                    "can_teleport": true
                }
            }
        },
        "components": {
            "minecraft:type_family": {
                "family": ["turtle", "mob", "animal"]
            },
            "minecraft:collision_box": {
                "width": 1.2,
                "height": 0.4
            },
            "minecraft:health": {
                "value": 60,
                "max": 60
            },
            "minecraft:movement": {
                "value": 0.35
            },
            "minecraft:attack": {
                "damage": 6
            },
            "minecraft:navigation.walk": {
                "can_path_over_water": true,
                "avoid_water": false,
                "can_float": true
            },
            "minecraft:movement.basic": {},
            "minecraft:physics": {},
            "minecraft:pushable": {
                "is_pushable": true,
                "is_pushable_by_piston": true
            },
            "minecraft:persistent": {},
            "minecraft:breathable": {
                "total_supply": 15,
                "suffocate_time": 0,
                "breathes_water": true,
                "breathes_air": true
            },
            "minecraft:knockback_resistance": {
                "value": 0.8
            },
            "minecraft:damage_sensor": {
                "triggers": [
                    {
                        "cause": "all",
                        "deals_damage": true
                    }
                ]
            },
            "minecraft:behavior.nearest_attackable_target": {
                "priority": 1,
                "within_radius": 12,
                "must_see": true,
                "reselect_targets": true,
                "entity_types": [
                    {
                        "filters": {
                            "test": "is_family",
                            "subject": "other",
                            "value": "monster"
                        },
                        "max_dist": 12
                    }
                ]
            },
            "minecraft:behavior.melee_attack": {
                "priority": 3,
                "speed_multiplier": 1.4,
                "track_target": true
            },
            "minecraft:behavior.random_stroll": {
                "priority": 8,
                "speed_multiplier": 0.6,
                "xz_dist": 3,
                "y_dist": 1
            },
            "minecraft:behavior.look_at_player": {
                "priority": 9,
                "look_distance": 8,
                "probability": 0.1
            },
            "minecraft:behavior.float": {
                "priority": 0
            }
        },
        "events": {
            "little:tame": {
                "add": {
                    "component_groups": ["little:tamed"]
                }
            }
        }
    }
}
```

Key design choices:
- Health: 60 (30 hearts — beefy protector)
- Attack damage: 6 (3 hearts per hit)
- `nearest_attackable_target` filters for `monster` family — auto-targets hostile mobs
- `melee_attack` with speed_multiplier 1.4 — charges threats quickly
- Knockback resistance 0.8 — stands firm
- Movement 0.35 — much faster than vanilla turtle (0.1)

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/entities/shelly.json
git commit -m "feat: add Shelly (turtle) entity definition"
```

---

### Task 5: Entity JSON — Bamboo (Panda Companion)

**Files:**
- Create: `little-friends-bp/entities/bamboo.json`

- [ ] **Step 1: Create Bamboo entity definition**

Create `little-friends-bp/entities/bamboo.json`:

```json
{
    "format_version": "1.21.0",
    "minecraft:entity": {
        "description": {
            "identifier": "little:bamboo",
            "is_spawnable": false,
            "is_summonable": true,
            "is_experimental": false
        },
        "component_groups": {
            "little:tamed": {
                "minecraft:is_tamed": {},
                "minecraft:behavior.follow_owner": {
                    "priority": 2,
                    "speed_multiplier": 1.3,
                    "start_distance": 8,
                    "stop_distance": 3,
                    "can_teleport": true
                }
            }
        },
        "components": {
            "minecraft:type_family": {
                "family": ["panda", "mob", "animal"]
            },
            "minecraft:collision_box": {
                "width": 1.3,
                "height": 1.25
            },
            "minecraft:health": {
                "value": 40,
                "max": 40
            },
            "minecraft:movement": {
                "value": 0.2
            },
            "minecraft:navigation.walk": {
                "can_path_over_water": true,
                "avoid_water": true,
                "can_float": true
            },
            "minecraft:movement.basic": {},
            "minecraft:physics": {},
            "minecraft:pushable": {
                "is_pushable": true,
                "is_pushable_by_piston": true
            },
            "minecraft:persistent": {},
            "minecraft:breathable": {
                "total_supply": 15,
                "suffocate_time": 0,
                "breathes_air": true
            },
            "minecraft:knockback_resistance": {
                "value": 0.2
            },
            "minecraft:damage_sensor": {
                "triggers": [
                    {
                        "cause": "all",
                        "deals_damage": true
                    }
                ]
            },
            "minecraft:behavior.random_stroll": {
                "priority": 8,
                "speed_multiplier": 0.7,
                "xz_dist": 5,
                "y_dist": 2
            },
            "minecraft:behavior.look_at_player": {
                "priority": 9,
                "look_distance": 8,
                "probability": 0.1
            },
            "minecraft:behavior.float": {
                "priority": 0
            }
        },
        "events": {
            "little:tame": {
                "add": {
                    "component_groups": ["little:tamed"]
                }
            }
        }
    }
}
```

Key design choices:
- Health: 40 (20 hearts)
- Wanderer stroll range larger (xz_dist: 5) — wanders further to "forage"
- No attack components — Bamboo is a peaceful gatherer
- `avoid_water: true` — pandas don't swim

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/entities/bamboo.json
git commit -m "feat: add Bamboo (panda) entity definition"
```

---

### Task 6: Resource Pack — Client Entities and Render Controllers

**Files:**
- Create: `little-friends-rp/entity/axie.entity.json`
- Create: `little-friends-rp/entity/shelly.entity.json`
- Create: `little-friends-rp/entity/bamboo.entity.json`
- Create: `little-friends-rp/render_controllers/little_friends.render_controllers.json`

- [ ] **Step 1: Create Axie client entity**

Create `little-friends-rp/entity/axie.entity.json`:

```json
{
    "format_version": "1.10.0",
    "minecraft:client_entity": {
        "description": {
            "identifier": "little:axie",
            "materials": {
                "default": "entity_alphatest"
            },
            "textures": {
                "default": "textures/entity/axie/axie"
            },
            "geometry": {
                "default": "geometry.axolotl"
            },
            "render_controllers": [
                "controller.render.little_axie"
            ],
            "animations": {
                "general": "animation.axolotl.general",
                "look_at_target": "animation.common.look_at_target"
            },
            "scripts": {
                "animate": [
                    "general",
                    "look_at_target"
                ]
            }
        }
    }
}
```

- [ ] **Step 2: Create Shelly client entity**

Create `little-friends-rp/entity/shelly.entity.json`:

```json
{
    "format_version": "1.10.0",
    "minecraft:client_entity": {
        "description": {
            "identifier": "little:shelly",
            "materials": {
                "default": "entity_alphatest"
            },
            "textures": {
                "default": "textures/entity/shelly/shelly"
            },
            "geometry": {
                "default": "geometry.turtle"
            },
            "render_controllers": [
                "controller.render.little_shelly"
            ],
            "animations": {
                "walk": "animation.turtle.walk",
                "look_at_target": "animation.common.look_at_target"
            },
            "scripts": {
                "animate": [
                    "walk",
                    "look_at_target"
                ]
            }
        }
    }
}
```

- [ ] **Step 3: Create Bamboo client entity**

Create `little-friends-rp/entity/bamboo.entity.json`:

```json
{
    "format_version": "1.10.0",
    "minecraft:client_entity": {
        "description": {
            "identifier": "little:bamboo",
            "materials": {
                "default": "entity_alphatest"
            },
            "textures": {
                "default": "textures/entity/bamboo/bamboo"
            },
            "geometry": {
                "default": "geometry.panda"
            },
            "render_controllers": [
                "controller.render.little_bamboo"
            ],
            "animations": {
                "general": "animation.panda.general_pose",
                "look_at_target": "animation.common.look_at_target"
            },
            "scripts": {
                "animate": [
                    "general",
                    "look_at_target"
                ]
            }
        }
    }
}
```

- [ ] **Step 4: Create render controllers**

Create `little-friends-rp/render_controllers/little_friends.render_controllers.json`:

```json
{
    "format_version": "1.8.0",
    "render_controllers": {
        "controller.render.little_axie": {
            "geometry": "Geometry.default",
            "materials": [{ "*": "Material.default" }],
            "textures": ["Texture.default"]
        },
        "controller.render.little_shelly": {
            "geometry": "Geometry.default",
            "materials": [{ "*": "Material.default" }],
            "textures": ["Texture.default"]
        },
        "controller.render.little_bamboo": {
            "geometry": "Geometry.default",
            "materials": [{ "*": "Material.default" }],
            "textures": ["Texture.default"]
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add little-friends-rp/entity/ little-friends-rp/render_controllers/
git commit -m "feat: add client entity definitions and render controllers"
```

---

### Task 7: Custom Textures

**Files:**
- Create: `little-friends-rp/textures/entity/axie/axie.png`
- Create: `little-friends-rp/textures/entity/shelly/shelly.png`
- Create: `little-friends-rp/textures/entity/bamboo/bamboo.png`

The vanilla textures are 64x64 for axolotl/turtle and 64x64 for panda. We need to create custom versions.

- [ ] **Step 1: Extract vanilla textures as reference**

Extract the vanilla textures from the game files to use as a base:

```bash
# Axolotl texture (lucy variant — the pink one)
cp ~/Games/minecraft-bedrock-edition-lutris/game/data/resource_packs/vanilla/textures/entity/axolotl/axolotl_lucy.png /tmp/axolotl_base.png

# Turtle texture
cp ~/Games/minecraft-bedrock-edition-lutris/game/data/resource_packs/vanilla/textures/entity/turtle/big_sea_turtle.png /tmp/turtle_base.png

# Panda texture
cp ~/Games/minecraft-bedrock-edition-lutris/game/data/resource_packs/vanilla/textures/entity/panda/panda.png /tmp/panda_base.png
```

If paths differ, search:
```bash
find ~/Games/minecraft-bedrock-edition-lutris/game/data -name "axolotl_lucy.png" -o -name "big_sea_turtle.png" -o -name "panda.png" 2>/dev/null
```

- [ ] **Step 2: Create Axie texture (pastel pink sparkle)**

Use Python PIL/Pillow to modify the vanilla axolotl_lucy texture — shift hue toward pastel pink and add sparkle dots:

```python
from PIL import Image, ImageDraw
import random

img = Image.open('/tmp/axolotl_base.png').convert('RGBA')
pixels = img.load()
w, h = img.size

# Shift to pastel pink — increase red, decrease green slightly
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a > 0:
            r = min(255, int(r * 1.15) + 30)
            g = max(0, int(g * 0.85))
            b = min(255, int(b * 1.05) + 20)
            pixels[x, y] = (r, g, b, a)

# Add small white sparkle dots
draw = ImageDraw.Draw(img)
for _ in range(8):
    sx = random.randint(0, w - 1)
    sy = random.randint(0, h - 1)
    if pixels[sx, sy][3] > 0:
        draw.point((sx, sy), fill=(255, 255, 255, 220))

img.save('little-friends-rp/textures/entity/axie/axie.png')
```

- [ ] **Step 3: Create Shelly texture (backpack on shell)**

Modify the turtle texture — darken the shell slightly and add a brown rectangle "backpack" on the top shell area:

```python
from PIL import Image, ImageDraw

img = Image.open('/tmp/turtle_base.png').convert('RGBA')
draw = ImageDraw.Draw(img)

# The turtle shell texture is mapped on the top section of the texture file
# Add a brown backpack rectangle on the shell area (approximate UV region)
# Turtle texture layout: shell top is roughly at (5,5) to (22,18) on a 64x32 texture
backpack_color = (139, 90, 43, 255)  # brown
strap_color = (100, 65, 30, 255)     # darker brown

# Small backpack on top of shell
draw.rectangle([10, 7, 17, 13], fill=backpack_color, outline=strap_color)
# Strap across
draw.line([10, 10, 17, 10], fill=strap_color, width=1)

img.save('little-friends-rp/textures/entity/shelly/shelly.png')
```

- [ ] **Step 4: Create Bamboo texture (flower crown)**

Modify the panda texture — add small flower/petal details on the head area:

```python
from PIL import Image, ImageDraw

img = Image.open('/tmp/panda_base.png').convert('RGBA')
draw = ImageDraw.Draw(img)

# Panda head top is in the texture atlas — add flower dots
# Head top UV area is approximately (8, 0) to (16, 8) on a 64x64 texture
flower_colors = [
    (255, 105, 180, 255),  # pink
    (255, 215, 0, 255),    # gold
    (147, 112, 219, 255),  # purple
    (255, 160, 122, 255),  # salmon
]

# Place small 2x2 flower dots across the head top
flower_positions = [(9, 1), (12, 0), (14, 2), (10, 3), (13, 3)]
for i, (fx, fy) in enumerate(flower_positions):
    color = flower_colors[i % len(flower_colors)]
    draw.rectangle([fx, fy, fx + 1, fy + 1], fill=color)

# Green leaf accents
leaf_color = (34, 139, 34, 255)
draw.point((11, 1), fill=leaf_color)
draw.point((13, 1), fill=leaf_color)

img.save('little-friends-rp/textures/entity/bamboo/bamboo.png')
```

- [ ] **Step 5: Verify textures exist**

```bash
file little-friends-rp/textures/entity/axie/axie.png
file little-friends-rp/textures/entity/shelly/shelly.png
file little-friends-rp/textures/entity/bamboo/bamboo.png
```

All should report `PNG image data`.

- [ ] **Step 6: Commit**

```bash
git add little-friends-rp/textures/
git commit -m "feat: add custom textures for all three companions"
```

---

### Task 8: Script — Utils Module

**Files:**
- Create: `little-friends-bp/scripts/utils.js`

- [ ] **Step 1: Create utils.js**

Create `little-friends-bp/scripts/utils.js`:

```javascript
/**
 * Shared utility functions for Little Friends add-on.
 */

/**
 * Calculate horizontal distance between two positions.
 * @param {import('@minecraft/server').Vector3} a
 * @param {import('@minecraft/server').Vector3} b
 * @returns {number}
 */
export function distanceXZ(a, b) {
    const dx = a.x - b.x;
    const dz = a.z - b.z;
    return Math.sqrt(dx * dx + dz * dz);
}

/**
 * Calculate 3D distance between two positions.
 * @param {import('@minecraft/server').Vector3} a
 * @param {import('@minecraft/server').Vector3} b
 * @returns {number}
 */
export function distance3D(a, b) {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/**
 * Get a position offset from a player's location in their facing direction.
 * @param {import('@minecraft/server').Player} player
 * @param {number} forward - blocks forward
 * @param {number} right - blocks right
 * @returns {import('@minecraft/server').Vector3}
 */
export function offsetFromPlayer(player, forward, right) {
    const rot = player.getRotation();
    const yawRad = (rot.y * Math.PI) / 180;
    // Minecraft: yaw 0 = south (+z), 90 = west (-x)
    const fx = -Math.sin(yawRad);
    const fz = Math.cos(yawRad);
    const rx = Math.cos(yawRad);
    const rz = Math.sin(yawRad);
    const loc = player.location;
    return {
        x: Math.floor(loc.x + fx * forward + rx * right),
        y: Math.floor(loc.y),
        z: Math.floor(loc.z + fz * forward + rz * right)
    };
}

/**
 * Get the cardinal direction the player is facing as offsets.
 * @param {import('@minecraft/server').Player} player
 * @returns {{ dx: number, dz: number }} unit offsets in facing direction
 */
export function playerFacingDirection(player) {
    const rot = player.getRotation();
    const yaw = ((rot.y % 360) + 360) % 360;
    if (yaw >= 315 || yaw < 45) return { dx: 0, dz: 1 };   // south
    if (yaw >= 45 && yaw < 135) return { dx: -1, dz: 0 };  // west
    if (yaw >= 135 && yaw < 225) return { dx: 0, dz: -1 }; // north
    return { dx: 1, dz: 0 };                                 // east
}

/**
 * Pick a random element from an array.
 * @template T
 * @param {T[]} arr
 * @returns {T}
 */
export function randomChoice(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

/**
 * Get a random position near a location.
 * @param {import('@minecraft/server').Vector3} center
 * @param {number} minDist
 * @param {number} maxDist
 * @returns {import('@minecraft/server').Vector3}
 */
export function randomNearby(center, minDist, maxDist) {
    const angle = Math.random() * 2 * Math.PI;
    const dist = minDist + Math.random() * (maxDist - minDist);
    return {
        x: Math.floor(center.x + Math.cos(angle) * dist),
        y: center.y,
        z: Math.floor(center.z + Math.sin(angle) * dist)
    };
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/utils.js
git commit -m "feat: add shared utility functions"
```

---

### Task 9: Script — Communicator Module

**Files:**
- Create: `little-friends-bp/scripts/companions/communicator.js`

- [ ] **Step 1: Create communicator.js**

Create `little-friends-bp/scripts/companions/communicator.js`:

```javascript
/**
 * Companion personality messages and action bar communication.
 */
import { world } from '@minecraft/server';
import { randomChoice } from '../utils.js';

const IDLE_MESSAGES = {
    'little:axie': [
        'La la la... building is fun!',
        'Ooh, what should we build next?',
        'I love exploring with you!',
        'Do you like my buildings?',
        'Axie is happy!',
        'Look at all these blocks!',
    ],
    'little:shelly': [
        "Don't worry, Shelly's here!",
        'Hmm... it\'s quiet. Too quiet.',
        'Yay! Daytime is the best!',
        "I'll stay close tonight.",
        'Shelly is on guard!',
        'You are safe with me!',
    ],
    'little:bamboo': [
        '...yawn...',
        'Bamboo is sleepy...',
        'Mmm, I smell something nice!',
        "I'll go look around soon!",
        'Bamboo loves flowers!',
        '...munch munch...',
    ],
};

const EVENT_MESSAGES = {
    axie_building: [
        'Ooh! I\'ll build that right away!',
        'Building time! Yay!',
        'Leave it to Axie!',
    ],
    axie_done: [
        'Ta-da! Do you like it?',
        'All done! Pretty, right?',
        'Axie built it just for you!',
    ],
    axie_night_shelter: [
        'It\'s getting dark! Let me build a house!',
        'Time for a cozy shelter!',
    ],
    shelly_warning: [
        'Shelly hears something scary...',
        'Something is coming...',
        'Stay close to Shelly!',
    ],
    shelly_fighting: [
        'Stay behind me!',
        "I'll protect you!",
        'Shelly to the rescue!',
    ],
    shelly_safe: [
        'All safe now!',
        'The scary thing is gone!',
        'Shelly kept you safe!',
    ],
    bamboo_gift: [
        'Here you go! A present!',
        'Bamboo found something!',
        '...yawn... oh! Look what I found!',
    ],
    bamboo_foraging: [
        "I'll go look around... be right back!",
        'Bamboo smells something good nearby!',
    ],
    bamboo_pickup: [
        'Ooh, you dropped this!',
        'Bamboo picked that up for you!',
    ],
    companion_scared: [
        'Eek!',
        'That was loud!',
        '...Bamboo doesn\'t like that!',
    ],
    companion_teleport: [
        'Wait for me!',
        "I'm coming!",
        'Whoosh!',
    ],
};

const INTRO_MESSAGES = {
    'little:axie': 'Hi new friend! I\'m Axie! Let\'s build stuff!',
    'little:shelly': "Hello! I'm Shelly. I'll keep you safe!",
    'little:bamboo': '...yawn... oh hi! I\'m Bamboo. Want a flower?',
};

/**
 * Show a companion message to the nearest player via action bar.
 * @param {import('@minecraft/server').Entity} companion
 * @param {string} message
 */
export function say(companion, message) {
    const name = companion.typeId === 'little:axie' ? 'Axie'
        : companion.typeId === 'little:shelly' ? 'Shelly'
        : 'Bamboo';
    const players = companion.dimension.getPlayers({
        location: companion.location,
        maxDistance: 40,
    });
    for (const player of players) {
        player.onScreenDisplay.setActionBar(`[${name}] ${message}`);
    }
}

/**
 * Show a random idle message for a companion.
 * @param {import('@minecraft/server').Entity} companion
 */
export function sayIdle(companion) {
    const messages = IDLE_MESSAGES[companion.typeId];
    if (messages) {
        say(companion, randomChoice(messages));
    }
}

/**
 * Show an event-triggered message.
 * @param {import('@minecraft/server').Entity} companion
 * @param {string} eventKey
 */
export function sayEvent(companion, eventKey) {
    const messages = EVENT_MESSAGES[eventKey];
    if (messages) {
        say(companion, randomChoice(messages));
    }
}

/**
 * Show companion intro message.
 * @param {import('@minecraft/server').Entity} companion
 */
export function sayIntro(companion) {
    const message = INTRO_MESSAGES[companion.typeId];
    if (message) {
        say(companion, message);
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/companions/communicator.js
git commit -m "feat: add companion communicator with personality messages"
```

---

### Task 10: Script — Spawner Module

**Files:**
- Create: `little-friends-bp/scripts/companions/spawner.js`

- [ ] **Step 1: Create spawner.js**

Create `little-friends-bp/scripts/companions/spawner.js`:

```javascript
/**
 * Companion spawning, persistence, and respawn logic.
 *
 * Each companion is tagged with:
 * - "little_friend" (identifies all companions)
 * - "little_owner:<playerName>" (links to specific player)
 * - "little_type:axie|shelly|bamboo" (companion type)
 */
import { world, system } from '@minecraft/server';
import { randomNearby } from '../utils.js';
import { sayIntro } from './communicator.js';

const COMPANION_TYPES = ['little:axie', 'little:shelly', 'little:bamboo'];
const SPAWN_DELAYS = [600, 1200, 1800]; // 30s, 60s, 90s in ticks
const RESPAWN_DELAY = 200; // 10s in ticks

/**
 * Find existing companions for a player.
 * @param {import('@minecraft/server').Player} player
 * @returns {import('@minecraft/server').Entity[]}
 */
export function getCompanions(player) {
    return player.dimension.getEntities({
        tags: ['little_friend', `little_owner:${player.name}`],
    });
}

/**
 * Find a specific companion type for a player.
 * @param {import('@minecraft/server').Player} player
 * @param {string} typeId - e.g., 'little:axie'
 * @returns {import('@minecraft/server').Entity | undefined}
 */
export function getCompanion(player, typeId) {
    const typeName = typeId.replace('little:', '');
    const entities = player.dimension.getEntities({
        type: typeId,
        tags: ['little_friend', `little_owner:${player.name}`, `little_type:${typeName}`],
    });
    return entities[0];
}

/**
 * Spawn a single companion for a player.
 * @param {import('@minecraft/server').Player} player
 * @param {string} typeId
 */
function spawnCompanion(player, typeId) {
    const typeName = typeId.replace('little:', '');
    const spawnPos = randomNearby(player.location, 15, 20);

    try {
        const entity = player.dimension.spawnEntity(typeId, spawnPos);
        entity.addTag('little_friend');
        entity.addTag(`little_owner:${player.name}`);
        entity.addTag(`little_type:${typeName}`);
        entity.nameTag = typeName.charAt(0).toUpperCase() + typeName.slice(1);

        // Trigger the tame event so follow_owner activates
        entity.triggerEvent('little:tame');

        // Show sparkle particles at spawn
        player.dimension.spawnParticle('minecraft:villager_happy', spawnPos);

        // Intro message after a short delay
        system.runTimeout(() => {
            try { sayIntro(entity); } catch (_) {}
        }, 40);
    } catch (e) {
        // Spawn failed — will retry on next check
    }
}

/**
 * Start the staggered spawn sequence for a new player.
 * @param {import('@minecraft/server').Player} player
 */
export function beginSpawnSequence(player) {
    for (let i = 0; i < COMPANION_TYPES.length; i++) {
        const typeId = COMPANION_TYPES[i];
        system.runTimeout(() => {
            // Check the player is still online
            try {
                const loc = player.location; // throws if player left
            } catch (_) { return; }

            // Check if this companion already exists
            const existing = getCompanion(player, typeId);
            if (!existing) {
                spawnCompanion(player, typeId);
            }
        }, SPAWN_DELAYS[i]);
    }
}

/**
 * Check for missing companions and respawn them.
 * Called periodically from the main tick loop.
 * @param {import('@minecraft/server').Player} player
 */
export function checkAndRespawn(player) {
    const existing = getCompanions(player);
    const existingTypes = new Set(existing.map(e => e.typeId));

    for (const typeId of COMPANION_TYPES) {
        if (!existingTypes.has(typeId)) {
            // Companion is missing — respawn nearby
            const spawnPos = randomNearby(player.location, 3, 6);
            try {
                const entity = player.dimension.spawnEntity(typeId, spawnPos);
                const typeName = typeId.replace('little:', '');
                entity.addTag('little_friend');
                entity.addTag(`little_owner:${player.name}`);
                entity.addTag(`little_type:${typeName}`);
                entity.nameTag = typeName.charAt(0).toUpperCase() + typeName.slice(1);
                entity.triggerEvent('little:tame');

                // Poof particles
                player.dimension.spawnParticle('minecraft:large_explosion', spawnPos);
            } catch (_) {}
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/companions/spawner.js
git commit -m "feat: add companion spawner with persistence and respawn"
```

---

### Task 11: Script — Follower Module

**Files:**
- Create: `little-friends-bp/scripts/companions/follower.js`

- [ ] **Step 1: Create follower.js**

Create `little-friends-bp/scripts/companions/follower.js`:

```javascript
/**
 * Companion teleportation logic.
 * Entity JSON handles normal following via follow_owner behavior.
 * This module handles teleporting when companions are too far away.
 */
import { distanceXZ } from '../utils.js';
import { sayEvent } from './communicator.js';

const TELEPORT_DISTANCE = 30;

/**
 * Check if a companion needs to teleport to their owner.
 * Called every tick loop iteration for each companion.
 * @param {import('@minecraft/server').Entity} companion
 * @param {import('@minecraft/server').Player} owner
 */
export function updateFollowing(companion, owner) {
    const dist = distanceXZ(companion.location, owner.location);

    if (dist > TELEPORT_DISTANCE) {
        // Teleport near the player
        const angle = Math.random() * 2 * Math.PI;
        const offsetDist = 3 + Math.random() * 3;
        const dest = {
            x: owner.location.x + Math.cos(angle) * offsetDist,
            y: owner.location.y,
            z: owner.location.z + Math.sin(angle) * offsetDist,
        };

        try {
            companion.teleport(dest);
            // Poof particles
            owner.dimension.spawnParticle('minecraft:large_explosion', dest);
            sayEvent(companion, 'companion_teleport');
        } catch (_) {}
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/companions/follower.js
git commit -m "feat: add companion teleport-when-far-away logic"
```

---

### Task 12: Script — Building Templates

**Files:**
- Create: `little-friends-bp/scripts/templates/buildings.js`

- [ ] **Step 1: Create building templates**

Create `little-friends-bp/scripts/templates/buildings.js`:

Each template is an array of `{ x, y, z, block }` relative offsets. `x` is right, `y` is up, `z` is forward (from the player's perspective — rotated at build time).

```javascript
/**
 * Building templates for Axie.
 * Each template is an array of { x, y, z, block } relative offsets.
 * Origin (0,0,0) is the player's feet position.
 * z = forward (player facing direction), x = right, y = up.
 */

// 5x5 house with door, windows, torches, and roof
export const HOUSE = (() => {
    const blocks = [];
    const W = 'minecraft:oak_planks';
    const G = 'minecraft:glass';
    const D = 'minecraft:oak_door'; // bottom half
    const T = 'minecraft:torch';
    const S = 'minecraft:oak_slab'; // roof

    // Floor: 5x5 at y=0, starting 2 blocks forward
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 0, z, block: W });
        }
    }

    // Walls: 3 blocks high at y=1,2,3
    for (let y = 1; y <= 3; y++) {
        for (let x = -2; x <= 2; x++) {
            for (let z = 2; z <= 6; z++) {
                const isEdge = x === -2 || x === 2 || z === 2 || z === 6;
                if (!isEdge) continue;

                // Door opening at front center (z=2, x=0) at y=1,2
                if (z === 2 && x === 0 && y <= 2) continue;

                // Windows: glass at y=2 on sides
                if (y === 2 && ((x === -2 && z === 4) || (x === 2 && z === 4) || (z === 6 && x === 0))) {
                    blocks.push({ x, y, z, block: G });
                    continue;
                }

                blocks.push({ x, y, z, block: W });
            }
        }
    }

    // Roof: slabs at y=4
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 4, z, block: S });
        }
    }

    // Torches inside at y=3 on walls
    blocks.push({ x: -1, y: 3, z: 5, block: T });
    blocks.push({ x: 1, y: 3, z: 5, block: T });

    return blocks;
})();

// 3-high cobblestone wall in a circle (8-block radius)
export const WALL = (() => {
    const blocks = [];
    const W = 'minecraft:cobblestone';
    const radius = 8;

    for (let y = 1; y <= 3; y++) {
        for (let angle = 0; angle < 360; angle += 5) {
            const rad = (angle * Math.PI) / 180;
            const x = Math.round(Math.cos(rad) * radius);
            const z = Math.round(Math.sin(rad) * radius);
            blocks.push({ x, y, z, block: W });
        }
    }
    return blocks;
})();

// 10-block bridge forward
export const BRIDGE = (() => {
    const blocks = [];
    const W = 'minecraft:oak_planks';
    const F = 'minecraft:oak_fence';

    for (let z = 1; z <= 10; z++) {
        // 3-wide bridge deck at y=0
        blocks.push({ x: -1, y: 0, z, block: W });
        blocks.push({ x: 0, y: 0, z, block: W });
        blocks.push({ x: 1, y: 0, z, block: W });
        // Fences on sides
        blocks.push({ x: -2, y: 1, z, block: F });
        blocks.push({ x: 2, y: 1, z, block: F });
    }
    return blocks;
})();

// 5x5 farm with water channel
export const FARM = (() => {
    const blocks = [];
    const D = 'minecraft:farmland';
    const W = 'minecraft:water';

    // Water channel down the middle (z direction)
    for (let z = 2; z <= 6; z++) {
        blocks.push({ x: 0, y: 0, z, block: W });
    }

    // Farmland on both sides
    for (let z = 2; z <= 6; z++) {
        blocks.push({ x: -2, y: 0, z, block: D });
        blocks.push({ x: -1, y: 0, z, block: D });
        blocks.push({ x: 1, y: 0, z, block: D });
        blocks.push({ x: 2, y: 0, z, block: D });
    }
    return blocks;
})();

// 3x3 lookout tower, 8 blocks tall
export const TOWER = (() => {
    const blocks = [];
    const W = 'minecraft:cobblestone';
    const L = 'minecraft:ladder';
    const T = 'minecraft:torch';
    const S = 'minecraft:oak_slab';

    // Walls 8 high
    for (let y = 0; y <= 7; y++) {
        for (let x = -1; x <= 1; x++) {
            for (let z = 2; z <= 4; z++) {
                const isEdge = x === -1 || x === 1 || z === 2 || z === 4;
                if (!isEdge) continue;
                // Leave door at z=2, x=0, y=0,1
                if (z === 2 && x === 0 && y <= 1) continue;
                blocks.push({ x, y, z, block: W });
            }
        }
        // Ladder inside
        if (y <= 6) {
            blocks.push({ x: 0, y, z: 3, block: L });
        }
    }

    // Top platform
    for (let x = -1; x <= 1; x++) {
        for (let z = 2; z <= 4; z++) {
            blocks.push({ x, y: 8, z, block: S });
        }
    }

    // Torch on top
    blocks.push({ x: 0, y: 9, z: 3, block: T });

    return blocks;
})();

/**
 * Map of chat trigger words to templates.
 */
export const TEMPLATES = {
    house: HOUSE,
    wall: WALL,
    bridge: BRIDGE,
    farm: FARM,
    tower: TOWER,
};
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/templates/buildings.js
git commit -m "feat: add building templates (house, wall, bridge, farm, tower)"
```

---

### Task 13: Script — Builder Behavior (Axie)

**Files:**
- Create: `little-friends-bp/scripts/behaviors/builder.js`

- [ ] **Step 1: Create builder.js**

Create `little-friends-bp/scripts/behaviors/builder.js`:

```javascript
/**
 * Axie's building behavior — handles chat triggers and autonomous building.
 */
import { world, system } from '@minecraft/server';
import { TEMPLATES } from '../templates/buildings.js';
import { offsetFromPlayer, playerFacingDirection } from '../utils.js';
import { sayEvent } from '../companions/communicator.js';

/** @type {Map<string, { blocks: Array, index: number, dimension: any }>} */
const activeBuilds = new Map();

/**
 * Start building a template near a player.
 * @param {import('@minecraft/server').Entity} axie
 * @param {import('@minecraft/server').Player} player
 * @param {string} templateName
 */
export function startBuild(axie, player, templateName) {
    const template = TEMPLATES[templateName];
    if (!template || activeBuilds.has(player.name)) return;

    sayEvent(axie, 'axie_building');

    const facing = playerFacingDirection(player);
    const origin = player.location;

    // Rotate template blocks based on player facing
    const rotatedBlocks = template.map(b => {
        let rx, rz;
        if (facing.dz === 1) { rx = b.x; rz = b.z; }       // south (default)
        else if (facing.dz === -1) { rx = -b.x; rz = -b.z; } // north
        else if (facing.dx === -1) { rx = b.z; rz = -b.x; }  // west
        else { rx = -b.z; rz = b.x; }                         // east

        return {
            x: Math.floor(origin.x) + rx,
            y: Math.floor(origin.y) + b.y,
            z: Math.floor(origin.z) + rz,
            block: b.block,
        };
    });

    activeBuilds.set(player.name, {
        blocks: rotatedBlocks,
        index: 0,
        dimension: player.dimension,
        axie,
        player,
    });
}

/**
 * Tick the builder — place one block per call.
 * Call this every 2 ticks from the main loop.
 */
export function tickBuilder() {
    for (const [playerName, build] of activeBuilds) {
        if (build.index >= build.blocks.length) {
            // Building complete
            sayEvent(build.axie, 'axie_done');
            try {
                build.dimension.spawnParticle(
                    'minecraft:villager_happy',
                    build.axie.location
                );
            } catch (_) {}
            activeBuilds.delete(playerName);
            continue;
        }

        const b = build.blocks[build.index];
        try {
            build.dimension.setBlockType(
                { x: b.x, y: b.y, z: b.z },
                b.block
            );
            // Sparkle at placed block
            build.dimension.spawnParticle(
                'minecraft:villager_happy',
                { x: b.x + 0.5, y: b.y + 0.5, z: b.z + 0.5 }
            );
        } catch (_) {
            // Block placement failed (e.g., unloaded chunk) — skip
        }
        build.index++;
    }
}

/**
 * Check if Axie should autonomously build a shelter (sunset approaching).
 * @param {import('@minecraft/server').Entity} axie
 * @param {import('@minecraft/server').Player} player
 */
export function checkAutonomousBuild(axie, player) {
    // Only build at sunset if no active build
    if (activeBuilds.has(player.name)) return;

    const timeOfDay = world.getTimeOfDay();
    // Sunset is around 11000-12000 ticks
    if (timeOfDay >= 11000 && timeOfDay <= 11200) {
        sayEvent(axie, 'axie_night_shelter');
        startBuild(axie, player, 'house');
    }
}

/**
 * Handle a chat message — check for building trigger words.
 * @param {import('@minecraft/server').Player} player
 * @param {string} message
 * @param {import('@minecraft/server').Entity} axie
 * @returns {boolean} true if message was a build command
 */
export function handleChatCommand(player, message, axie) {
    const word = message.trim().toLowerCase();
    if (TEMPLATES[word]) {
        system.run(() => {
            startBuild(axie, player, word);
        });
        return true;
    }
    return false;
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/behaviors/builder.js
git commit -m "feat: add Axie builder behavior with chat triggers and auto-shelter"
```

---

### Task 14: Script — Protector Behavior (Shelly)

**Files:**
- Create: `little-friends-bp/scripts/behaviors/protector.js`

- [ ] **Step 1: Create protector.js**

Create `little-friends-bp/scripts/behaviors/protector.js`:

```javascript
/**
 * Shelly's protector behavior — warnings and nightlight effect.
 * Note: actual combat (targeting + melee attack) is handled by entity JSON behaviors.
 * This module handles the warning messages and visual effects.
 */
import { world } from '@minecraft/server';
import { distanceXZ } from '../utils.js';
import { sayEvent, say } from '../companions/communicator.js';

/** Track last warning time per player to avoid spam */
const lastWarning = new Map();
const WARNING_COOLDOWN = 200; // 10 seconds in ticks

/**
 * Check for nearby hostile mobs and send warnings.
 * @param {import('@minecraft/server').Entity} shelly
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function checkThreats(shelly, player, currentTick) {
    const lastWarnTick = lastWarning.get(player.name) || 0;
    if (currentTick - lastWarnTick < WARNING_COOLDOWN) return;

    // Find hostile mobs near the player
    const hostiles = player.dimension.getEntities({
        location: player.location,
        maxDistance: 20,
        families: ['monster'],
    });

    if (hostiles.length === 0) return;

    // Find closest hostile
    let closestDist = Infinity;
    for (const hostile of hostiles) {
        const d = distanceXZ(hostile.location, player.location);
        if (d < closestDist) closestDist = d;
    }

    if (closestDist <= 8) {
        sayEvent(shelly, 'shelly_fighting');
    } else if (closestDist <= 20) {
        sayEvent(shelly, 'shelly_warning');
    }

    lastWarning.set(player.name, currentTick);
}

/**
 * Post-combat message when no more threats nearby.
 * @param {import('@minecraft/server').Entity} shelly
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function checkSafe(shelly, player, currentTick) {
    const lastWarnTick = lastWarning.get(player.name) || 0;
    // Only say "safe" if we recently warned
    if (currentTick - lastWarnTick > WARNING_COOLDOWN && lastWarnTick > 0) return;
    if (currentTick - lastWarnTick < WARNING_COOLDOWN) return;

    const hostiles = player.dimension.getEntities({
        location: player.location,
        maxDistance: 20,
        families: ['monster'],
    });

    if (hostiles.length === 0 && lastWarnTick > 0) {
        sayEvent(shelly, 'shelly_safe');
        lastWarning.set(player.name, 0); // Reset
    }
}

/**
 * Emit nightlight particles around Shelly at night.
 * @param {import('@minecraft/server').Entity} shelly
 */
export function nightlightEffect(shelly) {
    const timeOfDay = world.getTimeOfDay();
    // Night: 13000-23000
    if (timeOfDay < 13000 || timeOfDay > 23000) return;

    try {
        shelly.dimension.spawnParticle(
            'minecraft:basic_flame_particle',
            {
                x: shelly.location.x + (Math.random() - 0.5) * 0.5,
                y: shelly.location.y + 0.5,
                z: shelly.location.z + (Math.random() - 0.5) * 0.5,
            }
        );
    } catch (_) {}
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/behaviors/protector.js
git commit -m "feat: add Shelly protector behavior with warnings and nightlight"
```

---

### Task 15: Script — Gatherer Behavior (Bamboo)

**Files:**
- Create: `little-friends-bp/scripts/behaviors/gatherer.js`

- [ ] **Step 1: Create gatherer.js**

Create `little-friends-bp/scripts/behaviors/gatherer.js`:

```javascript
/**
 * Bamboo's gatherer behavior — item pickup, gifting, and foraging.
 */
import { system, ItemStack } from '@minecraft/server';
import { distanceXZ, randomChoice } from '../utils.js';
import { sayEvent } from '../companions/communicator.js';

const GIFT_ITEMS = [
    'minecraft:poppy',
    'minecraft:dandelion',
    'minecraft:blue_orchid',
    'minecraft:oxeye_daisy',
    'minecraft:cornflower',
    'minecraft:wheat_seeds',
    'minecraft:beetroot_seeds',
    'minecraft:sweet_berries',
    'minecraft:brown_mushroom',
    'minecraft:bamboo',
    'minecraft:sugar_cane',
    'minecraft:apple',
];

const SNEEZE_ITEMS = [
    'minecraft:slime_ball',
    'minecraft:wheat_seeds',
    'minecraft:poppy',
];

/** Track last gift time per player */
const lastGiftTime = new Map();
const GIFT_INTERVAL = 2400; // ~2 minutes in ticks

/** Track last sneeze per player */
const lastSneezeTime = new Map();
const SNEEZE_INTERVAL = 4800; // ~4 minutes in ticks

/**
 * Pick up nearby dropped items and move them to the player.
 * @param {import('@minecraft/server').Entity} bamboo
 * @param {import('@minecraft/server').Player} player
 */
export function pickupItems(bamboo, player) {
    const items = bamboo.dimension.getEntities({
        type: 'minecraft:item',
        location: bamboo.location,
        maxDistance: 8,
    });

    for (const item of items) {
        // Teleport the item to the player
        try {
            const d = distanceXZ(item.location, player.location);
            if (d > 2) {
                item.teleport({
                    x: player.location.x + (Math.random() - 0.5),
                    y: player.location.y,
                    z: player.location.z + (Math.random() - 0.5),
                });
                sayEvent(bamboo, 'bamboo_pickup');
                break; // One item per tick to avoid spam
            }
        } catch (_) {}
    }
}

/**
 * Periodically give the player a random gift.
 * @param {import('@minecraft/server').Entity} bamboo
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function giftPlayer(bamboo, player, currentTick) {
    const lastGift = lastGiftTime.get(player.name) || 0;
    if (currentTick - lastGift < GIFT_INTERVAL) return;

    const itemType = randomChoice(GIFT_ITEMS);
    try {
        const itemStack = new ItemStack(itemType, 1);
        bamboo.dimension.spawnItem(
            itemStack,
            {
                x: bamboo.location.x,
                y: bamboo.location.y + 0.5,
                z: bamboo.location.z,
            }
        );
        sayEvent(bamboo, 'bamboo_gift');
        // Note particles
        bamboo.dimension.spawnParticle(
            'minecraft:note_particle',
            { x: bamboo.location.x, y: bamboo.location.y + 1, z: bamboo.location.z }
        );
    } catch (_) {}

    lastGiftTime.set(player.name, currentTick);
}

/**
 * Random sneeze that drops a bonus item.
 * @param {import('@minecraft/server').Entity} bamboo
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function checkSneeze(bamboo, player, currentTick) {
    const lastSneeze = lastSneezeTime.get(player.name) || 0;
    if (currentTick - lastSneeze < SNEEZE_INTERVAL) return;

    // 5% chance per check
    if (Math.random() > 0.05) return;

    const itemType = randomChoice(SNEEZE_ITEMS);
    try {
        const itemStack = new ItemStack(itemType, 1);
        bamboo.dimension.spawnItem(
            itemStack,
            {
                x: bamboo.location.x + (Math.random() - 0.5) * 2,
                y: bamboo.location.y + 0.5,
                z: bamboo.location.z + (Math.random() - 0.5) * 2,
            }
        );
        // Cloud particles for sneeze
        bamboo.dimension.spawnParticle(
            'minecraft:large_explosion',
            { x: bamboo.location.x, y: bamboo.location.y + 0.8, z: bamboo.location.z }
        );
    } catch (_) {}

    lastSneezeTime.set(player.name, currentTick);
}
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/behaviors/gatherer.js
git commit -m "feat: add Bamboo gatherer behavior with gifts and sneeze"
```

---

### Task 16: Script — Main Entry Point

**Files:**
- Create: `little-friends-bp/scripts/main.js`

- [ ] **Step 1: Create main.js**

Create `little-friends-bp/scripts/main.js`:

```javascript
/**
 * Little Friends — Main entry point.
 * Registers event handlers and runs the companion tick loop.
 */
import { world, system } from '@minecraft/server';
import { beginSpawnSequence, getCompanion, getCompanions, checkAndRespawn } from './companions/spawner.js';
import { updateFollowing } from './companions/follower.js';
import { sayIdle, sayEvent } from './companions/communicator.js';
import { handleChatCommand, tickBuilder, checkAutonomousBuild } from './behaviors/builder.js';
import { checkThreats, checkSafe, nightlightEffect } from './behaviors/protector.js';
import { pickupItems, giftPlayer, checkSneeze } from './behaviors/gatherer.js';
import { randomChoice, distanceXZ } from './utils.js';

/** Track which players have had companions spawned */
const initializedPlayers = new Set();

// --- Player spawn: trigger companion spawn sequence ---
world.afterEvents.playerSpawn.subscribe((event) => {
    if (!event.initialSpawn) return;
    const player = event.player;

    if (initializedPlayers.has(player.name)) return;
    initializedPlayers.add(player.name);

    // Check if companions already exist (world reload)
    const existing = getCompanions(player);
    if (existing.length >= 3) return;

    beginSpawnSequence(player);
});

// --- Chat commands (requires Beta APIs) ---
world.beforeEvents.chatSend.subscribe((event) => {
    const message = event.message;
    const player = event.sender;

    const axie = getCompanion(player, 'little:axie');
    if (axie && handleChatCommand(player, message, axie)) {
        event.cancel = true; // Don't show the command in chat
    }
});

// --- Main tick loop (runs every 20 ticks = 1 second) ---
let tickCount = 0;

system.runInterval(() => {
    tickCount++;
    const currentTick = system.currentTick;

    for (const player of world.getPlayers()) {
        // Respawn check every 10 seconds
        if (tickCount % 10 === 0) {
            checkAndRespawn(player);
        }

        const axie = getCompanion(player, 'little:axie');
        const shelly = getCompanion(player, 'little:shelly');
        const bamboo = getCompanion(player, 'little:bamboo');

        // --- Follower teleport checks ---
        if (axie) updateFollowing(axie, player);
        if (shelly) updateFollowing(shelly, player);
        if (bamboo) updateFollowing(bamboo, player);

        // --- Axie: autonomous building ---
        if (axie) checkAutonomousBuild(axie, player);

        // --- Shelly: threat warnings + nightlight ---
        if (shelly) {
            checkThreats(shelly, player, currentTick);
            checkSafe(shelly, player, currentTick);
            nightlightEffect(shelly);
        }

        // --- Bamboo: item pickup, gifts, sneeze ---
        if (bamboo) {
            pickupItems(bamboo, player);
            giftPlayer(bamboo, player, currentTick);
            checkSneeze(bamboo, player, currentTick);
        }

        // --- Idle chatter (every 20-40 seconds, pick a random companion) ---
        if (tickCount % 25 === 0) {
            const companions = [axie, shelly, bamboo].filter(Boolean);
            if (companions.length > 0) {
                sayIdle(randomChoice(companions));
            }
        }
    }
}, 20);

// --- Builder tick (runs every 2 ticks for smooth block placement) ---
system.runInterval(() => {
    tickBuilder();
}, 2);

// --- Axie flower placement (every ~3 minutes, place a random flower) ---
system.runInterval(() => {
    for (const player of world.getPlayers()) {
        const axie = getCompanion(player, 'little:axie');
        if (!axie) continue;
        const flowers = [
            'minecraft:poppy', 'minecraft:dandelion', 'minecraft:blue_orchid',
            'minecraft:oxeye_daisy', 'minecraft:cornflower',
        ];
        const pos = {
            x: Math.floor(axie.location.x + (Math.random() - 0.5) * 4),
            y: Math.floor(axie.location.y),
            z: Math.floor(axie.location.z + (Math.random() - 0.5) * 4),
        };
        try {
            // Only place on grass/dirt
            const block = player.dimension.getBlock(pos);
            const below = player.dimension.getBlock({ x: pos.x, y: pos.y - 1, z: pos.z });
            if (block && below) {
                const belowType = below.typeId;
                if ((belowType === 'minecraft:grass_block' || belowType === 'minecraft:dirt')
                    && block.typeId === 'minecraft:air') {
                    player.dimension.setBlockType(pos, randomChoice(flowers));
                    player.dimension.spawnParticle('minecraft:villager_happy',
                        { x: pos.x + 0.5, y: pos.y + 0.5, z: pos.z + 0.5 });
                }
            }
        } catch (_) {}
    }
}, 3600); // ~3 minutes

// --- Fear reactions: scatter from explosions ---
world.afterEvents.explosion.subscribe((event) => {
    for (const player of world.getPlayers()) {
        const companions = getCompanions(player);
        for (const companion of companions) {
            const d = distanceXZ(companion.location, event.source?.location ?? { x: 0, y: 0, z: 0 });
            if (d < 10) {
                // Scatter away from explosion
                const dx = companion.location.x - (event.source?.location?.x ?? companion.location.x);
                const dz = companion.location.z - (event.source?.location?.z ?? companion.location.z);
                const len = Math.sqrt(dx * dx + dz * dz) || 1;
                try {
                    companion.teleport({
                        x: companion.location.x + (dx / len) * 5,
                        y: companion.location.y,
                        z: companion.location.z + (dz / len) * 5,
                    });
                    sayEvent(companion, 'companion_scared');
                } catch (_) {}
            }
        }
    }
});
```

- [ ] **Step 2: Commit**

```bash
git add little-friends-bp/scripts/main.js
git commit -m "feat: add main entry point wiring all companion systems"
```

---

### Task 17: Install Script

**Files:**
- Create: `scripts/install-addon.sh`

- [ ] **Step 1: Create the install script**

Create `scripts/install-addon.sh`:

```bash
#!/usr/bin/env bash
# Install Little Friends add-on to Minecraft Bedrock com.mojang directory.
# Symlinks packs into the development folders for hot-reload during dev.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BP_SRC="$SCRIPT_DIR/little-friends-bp"
RP_SRC="$SCRIPT_DIR/little-friends-rp"

COM_MOJANG="$HOME/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang"

DEV_BP="$COM_MOJANG/development_behavior_packs/little-friends-bp"
DEV_RP="$COM_MOJANG/development_resource_packs/little-friends-rp"

if [ ! -d "$COM_MOJANG" ]; then
    echo "ERROR: com.mojang not found at:"
    echo "  $COM_MOJANG"
    echo "Make sure Minecraft has been launched at least once."
    exit 1
fi

echo "Installing Little Friends add-on..."
echo ""

# Remove old symlinks/copies
rm -rf "$DEV_BP" "$DEV_RP"

# Symlink for development (auto-reload on changes)
ln -sf "$BP_SRC" "$DEV_BP"
ln -sf "$RP_SRC" "$DEV_RP"

echo "Behavior pack: $DEV_BP -> $BP_SRC"
echo "Resource pack: $DEV_RP -> $RP_SRC"
echo ""
echo "=== Installed ==="
echo ""
echo "Next steps:"
echo "  1. Launch Minecraft"
echo "  2. Create or edit a world"
echo "  3. In world settings, enable:"
echo "     - Beta APIs (under Experiments)"
echo "     - Little Friends (under Behavior Packs)"
echo "     - Little Friends Resources (under Resource Packs)"
echo "  4. Play! Your companions will arrive in ~30 seconds."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/install-addon.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/install-addon.sh
git commit -m "feat: add install script for Little Friends add-on"
```

---

### Task 18: Test Installation and Verify In-Game

- [ ] **Step 1: Run the install script**

```bash
./scripts/install-addon.sh
```

Expected output: symlinks created, instructions printed.

- [ ] **Step 2: Verify symlinks**

```bash
ls -la "$HOME/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_behavior_packs/little-friends-bp/manifest.json"
ls -la "$HOME/Games/minecraft-bedrock-edition-lutris/prefix/pfx/drive_c/users/steamuser/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/little-friends-rp/manifest.json"
```

Both should exist and point to the repo source files.

- [ ] **Step 3: Launch Minecraft and test**

```bash
cd ~/Games/minecraft-bedrock-edition-lutris && bash launch.sh
```

In-game:
1. Create a new world (or edit existing)
2. Under Experiments, enable "Beta APIs"
3. Under Behavior Packs, activate "Little Friends"
4. Under Resource Packs, activate "Little Friends Resources"
5. Enter the world and wait 30 seconds for Axie to appear
6. Verify: companions spawn, follow, show action bar messages
7. Type `house` in chat — verify Axie starts building
8. Wait for night — verify Shelly glows and warns of mobs
9. Wait for Bamboo gifts

- [ ] **Step 4: Commit any fixes**

If any adjustments were needed during testing, commit them:

```bash
git add -A  # Only if all changes are test fixes
git commit -m "fix: adjustments from in-game testing"
```
