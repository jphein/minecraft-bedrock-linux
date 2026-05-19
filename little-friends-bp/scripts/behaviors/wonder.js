/**
 * Wonder events for Little Friends add-on.
 * Fairy villages, sparkle tornados, pet parades, treasure hunts,
 * cloud kingdoms, dance parties, libraries, and wishing fountains.
 *
 * Called from the main tick loop via tickWonder().
 */
import { world, system, ItemStack } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

// --- Cooldown maps (one per feature, keyed by player name) ---
const fairyVillageCooldown    = new Map();
const sparkleTornadoCooldown  = new Map();
const petParadeCooldown       = new Map();
const treasureHuntCooldown    = new Map();
const cloudKingdomCooldown    = new Map();
const dancePartyCooldown      = new Map();
const libraryRoomCooldown     = new Map();
const wishingFountainCooldown = new Map();

// Intervals in ticks (main loop calls every 20 ticks = 1 second)
const FAIRY_VILLAGE_INTERVAL    = 14400; // ~12 minutes
const SPARKLE_TORNADO_INTERVAL  = 3600;  // ~3 minutes
const PET_PARADE_INTERVAL       = 9600;  // ~8 minutes
const TREASURE_HUNT_INTERVAL    = 12000; // ~10 minutes
const CLOUD_KINGDOM_INTERVAL    = 18000; // ~15 minutes
const DANCE_PARTY_INTERVAL      = 6000;  // ~5 minutes
const LIBRARY_ROOM_INTERVAL     = 14400; // ~12 minutes
const WISHING_FOUNTAIN_INTERVAL = 12000; // ~10 minutes

// ============================================================
// Helper: safe block placement
// ============================================================
function setBlock(dim, pos, type) {
    try { dim.setBlockType(pos, type); } catch (_) {}
}

function getBlockType(dim, pos) {
    try {
        const b = dim.getBlock(pos);
        return b ? b.typeId : null;
    } catch (_) { return null; }
}

function spawnParticle(dim, type, pos) {
    try { dim.spawnParticle(type, pos); } catch (_) {}
}

// ============================================================
// 1. FAIRY VILLAGE  (every ~12 minutes)
// ============================================================
function checkFairyVillage(player, currentTick) {
    const last = fairyVillageCooldown.get(player.name) || 0;
    if (currentTick - last < FAIRY_VILLAGE_INTERVAL) return;
    fairyVillageCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 12, 22);
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('A Fairy Village!');
    player.onScreenDisplay.setActionBar('Tiny fairies built a village nearby!');

    const houseColors = [
        'minecraft:pink_wool',
        'minecraft:light_blue_wool',
        'minecraft:yellow_wool',
        'minecraft:lime_wool',
        'minecraft:purple_wool',
    ];

    // House positions relative to village center (spread in ~20x20 area)
    const houseOffsets = [
        { x: -6, z: -6 }, { x: 5, z: -5 }, { x: -5, z: 5 },
        { x: 6, z: 4 }, { x: 0, z: -7 },
    ];

    // Build each tiny house (3x3, 2 blocks tall)
    for (let h = 0; h < 5; h++) {
        const hx = base.x + houseOffsets[h].x;
        const hz = base.z + houseOffsets[h].z;
        const wool = houseColors[h];

        // Floor
        for (let dx = 0; dx < 3; dx++) {
            for (let dz = 0; dz < 3; dz++) {
                setBlock(dim, { x: hx + dx, y: baseY, z: hz + dz }, 'minecraft:oak_planks');
            }
        }

        // Walls (2 blocks tall, hollow inside)
        for (let dy = 1; dy <= 2; dy++) {
            for (let dx = 0; dx < 3; dx++) {
                for (let dz = 0; dz < 3; dz++) {
                    if (dx === 0 || dx === 2 || dz === 0 || dz === 2) {
                        // Leave front door open (center of one wall)
                        if (dy === 1 && dx === 1 && dz === 0) continue;
                        setBlock(dim, { x: hx + dx, y: baseY + dy, z: hz + dz }, wool);
                    }
                }
            }
        }

        // Roof (slab on top)
        for (let dx = 0; dx < 3; dx++) {
            for (let dz = 0; dz < 3; dz++) {
                setBlock(dim, { x: hx + dx, y: baseY + 3, z: hz + dz }, wool);
            }
        }

        // Lantern on top of each house
        setBlock(dim, { x: hx + 1, y: baseY + 4, z: hz + 1 }, 'minecraft:lantern');

        // Tiny garden in front of house (flowers)
        const flowers = ['minecraft:poppy', 'minecraft:dandelion', 'minecraft:blue_orchid',
            'minecraft:cornflower', 'minecraft:oxeye_daisy', 'minecraft:allium'];
        for (let gx = -1; gx <= 3; gx++) {
            const gardenPos = { x: hx + gx, y: baseY + 1, z: hz - 1 };
            if (Math.random() > 0.4) {
                const below = { x: gardenPos.x, y: baseY, z: gardenPos.z };
                setBlock(dim, below, 'minecraft:grass_block');
                setBlock(dim, gardenPos, randomChoice(flowers));
            }
        }
    }

    // Central fountain (water + stone bricks)
    const cx = base.x;
    const cz = base.z;
    // Fountain base ring
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            const dist = Math.abs(dx) + Math.abs(dz);
            if (dist <= 2) {
                setBlock(dim, { x: cx + dx, y: baseY, z: cz + dz }, 'minecraft:stone_bricks');
            }
            if (dist <= 1 && !(dx === 0 && dz === 0)) {
                setBlock(dim, { x: cx + dx, y: baseY + 1, z: cz + dz }, 'minecraft:water');
            }
        }
    }
    // Center column
    setBlock(dim, { x: cx, y: baseY + 1, z: cz }, 'minecraft:stone_bricks');
    setBlock(dim, { x: cx, y: baseY + 2, z: cz }, 'minecraft:stone_bricks');
    setBlock(dim, { x: cx, y: baseY + 3, z: cz }, 'minecraft:sea_lantern');

    // Paths with fences connecting houses to center
    for (let h = 0; h < 5; h++) {
        const hx = base.x + houseOffsets[h].x + 1;
        const hz = base.z + houseOffsets[h].z;
        // Simple straight path segments toward center
        const steps = 3;
        const stepDx = (cx - hx) / steps;
        const stepDz = (cz - hz) / steps;
        for (let s = 0; s < steps; s++) {
            const px = Math.floor(hx + stepDx * s);
            const pz = Math.floor(hz + stepDz * s);
            setBlock(dim, { x: px, y: baseY, z: pz }, 'minecraft:gravel');
            // Fence alongside path
            if (s % 2 === 0) {
                setBlock(dim, { x: px + 1, y: baseY + 1, z: pz }, 'minecraft:oak_fence');
            }
        }
    }

    // Entrance gate
    setBlock(dim, { x: base.x, y: baseY + 1, z: base.z - 9 }, 'minecraft:oak_fence');
    setBlock(dim, { x: base.x + 1, y: baseY + 1, z: base.z - 9 }, 'minecraft:oak_fence');
    setBlock(dim, { x: base.x, y: baseY + 2, z: base.z - 9 }, 'minecraft:oak_fence');
    setBlock(dim, { x: base.x + 1, y: baseY + 2, z: base.z - 9 }, 'minecraft:oak_fence');
    setBlock(dim, { x: base.x, y: baseY + 3, z: base.z - 9 }, 'minecraft:lantern');
    setBlock(dim, { x: base.x + 1, y: baseY + 3, z: base.z - 9 }, 'minecraft:lantern');

    // Scatter mushrooms
    for (let i = 0; i < 8; i++) {
        const mx = base.x + Math.floor(Math.random() * 18) - 9;
        const mz = base.z + Math.floor(Math.random() * 18) - 9;
        const mushroom = Math.random() > 0.5 ? 'minecraft:red_mushroom' : 'minecraft:brown_mushroom';
        setBlock(dim, { x: mx, y: baseY + 1, z: mz }, mushroom);
    }

    // Extra lanterns scattered around
    for (let i = 0; i < 6; i++) {
        const lx = base.x + Math.floor(Math.random() * 16) - 8;
        const lz = base.z + Math.floor(Math.random() * 16) - 8;
        setBlock(dim, { x: lx, y: baseY + 1, z: lz }, 'minecraft:oak_fence');
        setBlock(dim, { x: lx, y: baseY + 2, z: lz }, 'minecraft:lantern');
    }

    // Sparkle particles all over the village
    for (let i = 0; i < 20; i++) {
        const px = base.x + Math.random() * 20 - 10;
        const pz = base.z + Math.random() * 20 - 10;
        spawnParticle(dim, 'minecraft:villager_happy', { x: px, y: baseY + 2, z: pz });
    }
}

// ============================================================
// 2. ANIMATED SPARKLE TORNADO  (every ~3 minutes)
// ============================================================
function checkSparkleTornado(player, currentTick) {
    const last = sparkleTornadoCooldown.get(player.name) || 0;
    if (currentTick - last < SPARKLE_TORNADO_INTERVAL) return;
    sparkleTornadoCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const center = randomNearby(loc, 5, 12);
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('Sparkle Tornado!');
    player.onScreenDisplay.setActionBar('Ooh, a swirling sparkle tornado!');

    let iteration = 0;
    const intervalId = system.runInterval(() => {
        if (iteration >= 60) {
            system.clearRun(intervalId);

            // Final burst of particles
            for (let i = 0; i < 30; i++) {
                const angle = Math.random() * Math.PI * 2;
                const r = Math.random() * 6;
                const burstPos = {
                    x: center.x + Math.cos(angle) * r,
                    y: baseY + Math.random() * 5,
                    z: center.z + Math.sin(angle) * r,
                };
                spawnParticle(dim, 'minecraft:heart_particle', burstPos);
                spawnParticle(dim, 'minecraft:villager_happy', burstPos);
            }

            // Drop flowers in a circle on the ground
            const flowers = ['minecraft:poppy', 'minecraft:dandelion', 'minecraft:blue_orchid',
                'minecraft:cornflower', 'minecraft:allium', 'minecraft:oxeye_daisy'];
            for (let i = 0; i < 12; i++) {
                const a = (i / 12) * Math.PI * 2;
                const fx = Math.floor(center.x + Math.cos(a) * 4);
                const fz = Math.floor(center.z + Math.sin(a) * 4);
                const flowerPos = { x: fx, y: baseY + 1, z: fz };
                const belowPos = { x: fx, y: baseY, z: fz };
                const belowType = getBlockType(dim, belowPos);
                if (belowType === 'minecraft:grass_block' || belowType === 'minecraft:dirt') {
                    setBlock(dim, flowerPos, randomChoice(flowers));
                }
            }
            return;
        }

        // Spiral upward: increasing radius, spiraling angle
        const progress = iteration / 60; // 0 to 1
        const height = progress * 15; // up to 15 blocks tall
        const maxRadius = 1 + progress * 4; // up to 5 blocks wide at top
        const particleCount = 5 + Math.floor(Math.random() * 4); // 5-8

        for (let p = 0; p < particleCount; p++) {
            const spiralAngle = (iteration * 0.3) + (p / particleCount) * Math.PI * 2;
            const radius = maxRadius * (0.5 + Math.random() * 0.5);
            const particlePos = {
                x: center.x + Math.cos(spiralAngle) * radius,
                y: baseY + height + Math.random() * 2,
                z: center.z + Math.sin(spiralAngle) * radius,
            };
            const particleType = p % 2 === 0 ? 'minecraft:heart_particle' : 'minecraft:villager_happy';
            spawnParticle(dim, particleType, particlePos);
        }

        iteration++;
    }, 2); // Every 2 ticks for smooth animation
}

// ============================================================
// 3. PET PARADE  (every ~8 minutes)
// ============================================================
const PET_NAMES = [
    'Princess', 'Fluffy', 'Sparkle', 'Cupcake',
    'Moonbeam', 'Stardust', 'Marshmallow', 'Cookie',
    'Buttercup', 'Jellybean',
];
const PET_TYPES = [
    'minecraft:cat', 'minecraft:wolf', 'minecraft:parrot',
    'minecraft:fox', 'minecraft:rabbit',
    'minecraft:cat', 'minecraft:wolf', 'minecraft:parrot',
    'minecraft:fox', 'minecraft:rabbit',
];

function checkPetParade(player, currentTick) {
    const last = petParadeCooldown.get(player.name) || 0;
    if (currentTick - last < PET_PARADE_INTERVAL) return;
    petParadeCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;

    player.onScreenDisplay.setTitle('A Pet Parade!');
    player.onScreenDisplay.setActionBar('Look at all the cute animals!');

    const petCount = 8 + Math.floor(Math.random() * 3); // 8-10
    const spawnedPets = [];

    // Spawn pets in a line behind the player
    const startX = Math.floor(loc.x) - 10;
    const startZ = Math.floor(loc.z) + 5;

    for (let i = 0; i < petCount; i++) {
        const petType = PET_TYPES[i % PET_TYPES.length];
        const petName = PET_NAMES[i % PET_NAMES.length];
        const spawnPos = { x: startX + i * 2, y: Math.floor(loc.y), z: startZ };
        try {
            const pet = dim.spawnEntity(petType, spawnPos);
            pet.nameTag = petName;
            pet.addTag('little_friends_parade');
            spawnedPets.push(pet);
        } catch (_) {}
    }

    // Animate: teleport pets along a path, then circle around player
    let step = 0;
    const pathLength = 15;
    const animId = system.runInterval(() => {
        if (step < pathLength) {
            // Walk past the player
            for (let i = 0; i < spawnedPets.length; i++) {
                try {
                    const pet = spawnedPets[i];
                    if (!pet || (typeof pet.isValid === 'function' ? !pet.isValid() : pet.isValid === false)) continue;
                    const targetX = startX + i * 2;
                    const targetZ = startZ - step * 1;
                    pet.teleport({ x: targetX, y: Math.floor(loc.y), z: targetZ });
                    // Hearts along the way
                    if (step % 3 === 0) {
                        spawnParticle(dim, 'minecraft:heart_particle', {
                            x: targetX + 0.5, y: Math.floor(loc.y) + 1.5, z: targetZ + 0.5,
                        });
                    }
                } catch (_) {}
            }
        } else if (step < pathLength + 10) {
            // Form circle around player
            const circleStep = step - pathLength;
            for (let i = 0; i < spawnedPets.length; i++) {
                try {
                    const pet = spawnedPets[i];
                    if (!pet || (typeof pet.isValid === 'function' ? !pet.isValid() : pet.isValid === false)) continue;
                    const angle = (i / spawnedPets.length) * Math.PI * 2;
                    const radius = 4 + circleStep * 0.1;
                    pet.teleport({
                        x: loc.x + Math.cos(angle) * radius,
                        y: Math.floor(loc.y),
                        z: loc.z + Math.sin(angle) * radius,
                    });
                } catch (_) {}
            }
            // Hearts burst
            for (let i = 0; i < 8; i++) {
                const angle = Math.random() * Math.PI * 2;
                spawnParticle(dim, 'minecraft:heart_particle', {
                    x: loc.x + Math.cos(angle) * 5,
                    y: Math.floor(loc.y) + 1 + Math.random() * 2,
                    z: loc.z + Math.sin(angle) * 5,
                });
            }
        } else {
            // Sparkle poof and remove
            system.clearRun(animId);
            for (const pet of spawnedPets) {
                try {
                    if (!pet || (typeof pet.isValid === 'function' ? !pet.isValid() : pet.isValid === false)) continue;
                    const petLoc = pet.location;
                    for (let p = 0; p < 5; p++) {
                        spawnParticle(dim, 'minecraft:villager_happy', {
                            x: petLoc.x + Math.random() - 0.5,
                            y: petLoc.y + Math.random() * 2,
                            z: petLoc.z + Math.random() - 0.5,
                        });
                    }
                    pet.kill();
                } catch (_) {}
            }
        }
        step++;
    }, 10); // Every 10 ticks (0.5 seconds per step)
}

// ============================================================
// 4. TREASURE HUNT TRAIL  (every ~10 minutes)
// ============================================================
function checkTreasureHunt(player, currentTick) {
    const last = treasureHuntCooldown.get(player.name) || 0;
    if (currentTick - last < TREASURE_HUNT_INTERVAL) return;
    treasureHuntCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('Follow the Treasure Trail!');
    player.onScreenDisplay.setActionBar('Glowing markers lead to treasure!');

    // Pick a direction for the trail to wind
    const baseAngle = Math.random() * Math.PI * 2;
    const markerColors = [
        'minecraft:red_wool', 'minecraft:orange_wool', 'minecraft:yellow_wool',
        'minecraft:lime_wool', 'minecraft:light_blue_wool', 'minecraft:blue_wool',
        'minecraft:purple_wool', 'minecraft:magenta_wool', 'minecraft:pink_wool',
        'minecraft:white_wool',
    ];

    const markers = [];
    for (let i = 0; i < 10; i++) {
        // Winding path: angle shifts with each marker
        const angle = baseAngle + (i * 0.3) + (Math.random() - 0.5) * 0.4;
        const dist = 3 + i * 3;
        const mx = Math.floor(loc.x + Math.cos(angle) * dist);
        const mz = Math.floor(loc.z + Math.sin(angle) * dist);
        markers.push({ x: mx, y: baseY, z: mz });

        // Sea lantern base with colored wool on top
        setBlock(dim, { x: mx, y: baseY, z: mz }, 'minecraft:sea_lantern');
        setBlock(dim, { x: mx, y: baseY + 1, z: mz }, markerColors[i]);

        // Sparkle at each marker
        spawnParticle(dim, 'minecraft:villager_happy', {
            x: mx + 0.5, y: baseY + 2, z: mz + 0.5,
        });
    }

    // Final treasure spot at the last marker
    const end = markers[markers.length - 1];
    const tx = end.x;
    const tz = end.z;

    // 3x3 gold platform
    for (let dx = -1; dx <= 1; dx++) {
        for (let dz = -1; dz <= 1; dz++) {
            setBlock(dim, { x: tx + dx, y: baseY, z: tz + dz }, 'minecraft:gold_block');
        }
    }

    // Diamond blocks surrounding (corners)
    setBlock(dim, { x: tx - 2, y: baseY, z: tz - 2 }, 'minecraft:diamond_block');
    setBlock(dim, { x: tx + 2, y: baseY, z: tz - 2 }, 'minecraft:diamond_block');
    setBlock(dim, { x: tx - 2, y: baseY, z: tz + 2 }, 'minecraft:diamond_block');
    setBlock(dim, { x: tx + 2, y: baseY, z: tz + 2 }, 'minecraft:diamond_block');

    // Torches and lanterns
    setBlock(dim, { x: tx - 2, y: baseY + 1, z: tz - 2 }, 'minecraft:torch');
    setBlock(dim, { x: tx + 2, y: baseY + 1, z: tz - 2 }, 'minecraft:torch');
    setBlock(dim, { x: tx - 2, y: baseY + 1, z: tz + 2 }, 'minecraft:lantern');
    setBlock(dim, { x: tx + 2, y: baseY + 1, z: tz + 2 }, 'minecraft:lantern');

    // Chest on the gold platform
    setBlock(dim, { x: tx, y: baseY + 1, z: tz }, 'minecraft:chest');

    // Spawn treasure items on the platform
    const treasurePos = { x: tx + 0.5, y: baseY + 2.5, z: tz + 0.5 };
    try { dim.spawnItem(new ItemStack('minecraft:diamond', 3), treasurePos); } catch (_) {}
    try { dim.spawnItem(new ItemStack('minecraft:emerald', 5), treasurePos); } catch (_) {}
    try { dim.spawnItem(new ItemStack('minecraft:golden_apple', 2), treasurePos); } catch (_) {}

    // Particles at treasure
    for (let i = 0; i < 15; i++) {
        spawnParticle(dim, 'minecraft:villager_happy', {
            x: tx + Math.random() * 4 - 2,
            y: baseY + 1 + Math.random() * 2,
            z: tz + Math.random() * 4 - 2,
        });
    }
}

// ============================================================
// 5. CLOUD KINGDOM  (every ~15 minutes)
// ============================================================
function checkCloudKingdom(player, currentTick) {
    const last = cloudKingdomCooldown.get(player.name) || 0;
    if (currentTick - last < CLOUD_KINGDOM_INTERVAL) return;
    cloudKingdomCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const baseY = Math.floor(loc.y);
    const cloudY = baseY + 30 + Math.floor(Math.random() * 11); // 30-40 above
    const cx = Math.floor(loc.x);
    const cz = Math.floor(loc.z);

    player.onScreenDisplay.setTitle('A Kingdom in the Clouds!');
    player.onScreenDisplay.setActionBar('Look up! A castle floats in the sky!');

    // Build cloud base (12x12 irregular blob)
    for (let dx = -6; dx <= 6; dx++) {
        for (let dz = -6; dz <= 6; dz++) {
            const dist = Math.sqrt(dx * dx + dz * dz);
            // Irregular edge with some noise
            const noise = (Math.sin(dx * 3.7) * 0.5 + Math.cos(dz * 2.3) * 0.5) * 1.5;
            if (dist < 5.5 + noise) {
                setBlock(dim, { x: cx + dx, y: cloudY, z: cz + dz }, 'minecraft:white_wool');
                // Thicker cloud: add layer below
                if (dist < 4) {
                    setBlock(dim, { x: cx + dx, y: cloudY - 1, z: cz + dz }, 'minecraft:white_wool');
                }
            }
        }
    }

    // Castle on the cloud
    const castleY = cloudY + 1;

    // Pink wool towers at 4 corners
    const towerPositions = [
        { x: cx - 4, z: cz - 4 }, { x: cx + 4, z: cz - 4 },
        { x: cx - 4, z: cz + 4 }, { x: cx + 4, z: cz + 4 },
    ];
    for (const tp of towerPositions) {
        for (let dy = 0; dy < 5; dy++) {
            setBlock(dim, { x: tp.x, y: castleY + dy, z: tp.z }, 'minecraft:pink_wool');
            setBlock(dim, { x: tp.x + 1, y: castleY + dy, z: tp.z }, 'minecraft:pink_wool');
            setBlock(dim, { x: tp.x, y: castleY + dy, z: tp.z + 1 }, 'minecraft:pink_wool');
            setBlock(dim, { x: tp.x + 1, y: castleY + dy, z: tp.z + 1 }, 'minecraft:pink_wool');
        }
        // Tower top: lantern
        setBlock(dim, { x: tp.x, y: castleY + 5, z: tp.z }, 'minecraft:lantern');
        setBlock(dim, { x: tp.x + 1, y: castleY + 5, z: tp.z + 1 }, 'minecraft:lantern');
    }

    // Walls between towers (2 blocks tall)
    for (let i = -3; i <= 4; i++) {
        for (let dy = 0; dy < 3; dy++) {
            // North wall
            setBlock(dim, { x: cx + i, y: castleY + dy, z: cz - 4 }, 'minecraft:pink_wool');
            // South wall
            setBlock(dim, { x: cx + i, y: castleY + dy, z: cz + 5 }, 'minecraft:pink_wool');
            // West wall
            setBlock(dim, { x: cx - 4, y: castleY + dy, z: cz + i }, 'minecraft:pink_wool');
            // East wall
            setBlock(dim, { x: cx + 5, y: castleY + dy, z: cz + i }, 'minecraft:pink_wool');
        }
    }

    // Glass windows in walls
    setBlock(dim, { x: cx, y: castleY + 1, z: cz - 4 }, 'minecraft:glass');
    setBlock(dim, { x: cx + 1, y: castleY + 1, z: cz - 4 }, 'minecraft:glass');
    setBlock(dim, { x: cx, y: castleY + 1, z: cz + 5 }, 'minecraft:glass');
    setBlock(dim, { x: cx + 1, y: castleY + 1, z: cz + 5 }, 'minecraft:glass');
    setBlock(dim, { x: cx - 4, y: castleY + 1, z: cz }, 'minecraft:glass');
    setBlock(dim, { x: cx + 5, y: castleY + 1, z: cz }, 'minecraft:glass');

    // Door opening (north wall center)
    setBlock(dim, { x: cx, y: castleY, z: cz - 4 }, 'minecraft:air');
    setBlock(dim, { x: cx, y: castleY + 1, z: cz - 4 }, 'minecraft:air');

    // Gold throne in the back
    setBlock(dim, { x: cx, y: castleY, z: cz + 3 }, 'minecraft:gold_block');
    setBlock(dim, { x: cx, y: castleY + 1, z: cz + 3 }, 'minecraft:gold_block');

    // Carpet leading to throne (red carpet)
    for (let i = -3; i <= 2; i++) {
        setBlock(dim, { x: cx, y: castleY, z: cz + i }, 'minecraft:red_carpet');
    }

    // Interior lanterns
    setBlock(dim, { x: cx - 2, y: castleY + 3, z: cz }, 'minecraft:lantern');
    setBlock(dim, { x: cx + 3, y: castleY + 3, z: cz }, 'minecraft:lantern');
    setBlock(dim, { x: cx, y: castleY + 3, z: cz + 2 }, 'minecraft:lantern');

    // Ladder from ground up to cloud
    for (let y = baseY; y <= cloudY; y++) {
        setBlock(dim, { x: cx - 5, y: y, z: cz }, 'minecraft:oak_planks');
        setBlock(dim, { x: cx - 4, y: y, z: cz }, 'minecraft:ladder');
    }

    // Sparkle particles around the cloud
    for (let i = 0; i < 25; i++) {
        spawnParticle(dim, 'minecraft:villager_happy', {
            x: cx + Math.random() * 14 - 7,
            y: cloudY + Math.random() * 4,
            z: cz + Math.random() * 14 - 7,
        });
    }
}

// ============================================================
// 6. DANCE PARTY  (every ~5 minutes)
// ============================================================
function checkDanceParty(player, currentTick) {
    const last = dancePartyCooldown.get(player.name) || 0;
    if (currentTick - last < DANCE_PARTY_INTERVAL) return;
    dancePartyCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 6, 14);
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('Dance Party!');
    player.onScreenDisplay.setActionBar('Time to dance!');

    // Dance floor colors (cycling concrete)
    const floorColors = [
        'minecraft:red_concrete', 'minecraft:orange_concrete',
        'minecraft:yellow_concrete', 'minecraft:lime_concrete',
        'minecraft:light_blue_concrete', 'minecraft:blue_concrete',
        'minecraft:purple_concrete', 'minecraft:pink_concrete',
    ];

    // 5x5 dance floor with alternating colors
    for (let dx = 0; dx < 5; dx++) {
        for (let dz = 0; dz < 5; dz++) {
            const color = floorColors[(dx + dz) % floorColors.length];
            setBlock(dim, { x: base.x + dx, y: baseY, z: base.z + dz }, color);
        }
    }

    // 4 jukeboxes at corners
    setBlock(dim, { x: base.x, y: baseY + 1, z: base.z }, 'minecraft:jukebox');
    setBlock(dim, { x: base.x + 4, y: baseY + 1, z: base.z }, 'minecraft:jukebox');
    setBlock(dim, { x: base.x, y: baseY + 1, z: base.z + 4 }, 'minecraft:jukebox');
    setBlock(dim, { x: base.x + 4, y: baseY + 1, z: base.z + 4 }, 'minecraft:jukebox');

    // Fence border with lanterns
    for (let dx = -1; dx <= 5; dx++) {
        for (let dz = -1; dz <= 5; dz++) {
            if (dx === -1 || dx === 5 || dz === -1 || dz === 5) {
                if ((dx + dz) % 2 === 0) {
                    setBlock(dim, { x: base.x + dx, y: baseY + 1, z: base.z + dz }, 'minecraft:oak_fence');
                    if ((dx + dz) % 4 === 0) {
                        setBlock(dim, { x: base.x + dx, y: baseY + 2, z: base.z + dz }, 'minecraft:lantern');
                    }
                }
            }
        }
    }

    // Disco ball: sea_lantern 3 blocks above center
    const centerX = base.x + 2;
    const centerZ = base.z + 2;
    setBlock(dim, { x: centerX, y: baseY + 4, z: centerZ }, 'minecraft:sea_lantern');

    // Animated dancing lights with particles
    let animTick = 0;
    const danceId = system.runInterval(() => {
        if (animTick >= 80) {
            system.clearRun(danceId);
            return;
        }

        // Note particles and hearts in rhythmic pattern
        const positions = 4 + Math.floor(Math.random() * 3);
        for (let p = 0; p < positions; p++) {
            const angle = (animTick * 0.2) + (p / positions) * Math.PI * 2;
            const r = 1.5 + Math.sin(animTick * 0.3) * 1;
            const px = centerX + 0.5 + Math.cos(angle) * r;
            const pz = centerZ + 0.5 + Math.sin(angle) * r;
            const py = baseY + 1.5 + Math.sin(animTick * 0.15 + p) * 0.5;

            const particleType = animTick % 4 < 2 ? 'minecraft:note_particle' : 'minecraft:heart_particle';
            spawnParticle(dim, particleType, { x: px, y: py, z: pz });
        }

        // Disco ball sparkle
        if (animTick % 3 === 0) {
            spawnParticle(dim, 'minecraft:villager_happy', {
                x: centerX + 0.5 + Math.random() - 0.5,
                y: baseY + 4.5,
                z: centerZ + 0.5 + Math.random() - 0.5,
            });
        }

        animTick++;
    }, 2);
}

// ============================================================
// 7. MAGICAL BOOKSHELF LIBRARY  (every ~12 minutes)
// ============================================================
function checkLibraryRoom(player, currentTick) {
    const last = libraryRoomCooldown.get(player.name) || 0;
    if (currentTick - last < LIBRARY_ROOM_INTERVAL) return;
    libraryRoomCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 8, 16);
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('A Magical Library!');
    player.onScreenDisplay.setActionBar('A cozy library appeared! So many books!');

    // 7x7 interior, 4 blocks tall — build outer shell 9x9 with stone bricks
    for (let dx = -1; dx <= 7; dx++) {
        for (let dz = -1; dz <= 7; dz++) {
            for (let dy = 0; dy <= 4; dy++) {
                const isWall = dx === -1 || dx === 7 || dz === -1 || dz === 7;
                const isFloor = dy === 0;
                const isCeiling = dy === 4;

                if (isFloor) {
                    // Mix of red and purple carpet on floor
                    const carpet = (dx + dz) % 2 === 0 ? 'minecraft:red_carpet' : 'minecraft:purple_carpet';
                    setBlock(dim, { x: base.x + dx, y: baseY + dy, z: base.z + dz },
                        isWall ? 'minecraft:stone_bricks' : carpet);
                } else if (isCeiling) {
                    setBlock(dim, { x: base.x + dx, y: baseY + dy, z: base.z + dz }, 'minecraft:oak_planks');
                } else if (isWall) {
                    // Walls: bookshelf blocks (inner face)
                    setBlock(dim, { x: base.x + dx, y: baseY + dy, z: base.z + dz }, 'minecraft:bookshelf');
                }
            }
        }
    }

    // Door opening (center of south wall)
    setBlock(dim, { x: base.x + 3, y: baseY + 1, z: base.z - 1 }, 'minecraft:air');
    setBlock(dim, { x: base.x + 3, y: baseY + 2, z: base.z - 1 }, 'minecraft:air');

    // Stone brick floor under the whole room
    for (let dx = -1; dx <= 7; dx++) {
        for (let dz = -1; dz <= 7; dz++) {
            setBlock(dim, { x: base.x + dx, y: baseY - 1, z: base.z + dz }, 'minecraft:stone_bricks');
        }
    }

    // Center: crafting table + enchanting table
    setBlock(dim, { x: base.x + 3, y: baseY + 1, z: base.z + 3 }, 'minecraft:crafting_table');
    setBlock(dim, { x: base.x + 3, y: baseY + 1, z: base.z + 4 }, 'minecraft:enchanting_table');

    // Reading nooks: stairs as chairs with slabs as tables
    // Left nook
    setBlock(dim, { x: base.x + 1, y: baseY + 1, z: base.z + 1 }, 'minecraft:oak_stairs');
    setBlock(dim, { x: base.x + 1, y: baseY + 1, z: base.z + 2 }, 'minecraft:oak_slab');
    // Right nook
    setBlock(dim, { x: base.x + 5, y: baseY + 1, z: base.z + 1 }, 'minecraft:oak_stairs');
    setBlock(dim, { x: base.x + 5, y: baseY + 1, z: base.z + 2 }, 'minecraft:oak_slab');

    // Lanterns hanging from ceiling
    setBlock(dim, { x: base.x + 1, y: baseY + 3, z: base.z + 1 }, 'minecraft:lantern');
    setBlock(dim, { x: base.x + 5, y: baseY + 3, z: base.z + 5 }, 'minecraft:lantern');
    setBlock(dim, { x: base.x + 3, y: baseY + 3, z: base.z + 3 }, 'minecraft:lantern');

    // Fireplace at the back wall (glowstone + stone brick surround)
    setBlock(dim, { x: base.x + 3, y: baseY + 1, z: base.z + 6 }, 'minecraft:glowstone');
    setBlock(dim, { x: base.x + 2, y: baseY + 1, z: base.z + 6 }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x + 4, y: baseY + 1, z: base.z + 6 }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x + 3, y: baseY + 2, z: base.z + 6 }, 'minecraft:glowstone');
    setBlock(dim, { x: base.x + 2, y: baseY + 2, z: base.z + 6 }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x + 4, y: baseY + 2, z: base.z + 6 }, 'minecraft:stone_bricks');

    // Spawn books as items
    const bookPos = { x: base.x + 3.5, y: baseY + 2.5, z: base.z + 3.5 };
    try { dim.spawnItem(new ItemStack('minecraft:book', 3), bookPos); } catch (_) {}
    try { dim.spawnItem(new ItemStack('minecraft:enchanted_book', 2), bookPos); } catch (_) {}
    try { dim.spawnItem(new ItemStack('minecraft:writable_book', 1), bookPos); } catch (_) {}

    // Cozy particles
    for (let i = 0; i < 12; i++) {
        spawnParticle(dim, 'minecraft:villager_happy', {
            x: base.x + Math.random() * 7,
            y: baseY + 1 + Math.random() * 2,
            z: base.z + Math.random() * 7,
        });
    }
}

// ============================================================
// 8. WISHING FOUNTAIN  (every ~10 minutes)
// ============================================================
function checkWishingFountain(player, currentTick) {
    const last = wishingFountainCooldown.get(player.name) || 0;
    if (currentTick - last < WISHING_FOUNTAIN_INTERVAL) return;
    wishingFountainCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 8, 18);
    const baseY = Math.floor(loc.y);

    player.onScreenDisplay.setTitle('Make a Wish!');
    player.onScreenDisplay.setActionBar('A magical wishing fountain appeared!');

    // Circular fountain ring (radius 4) with stone bricks
    for (let dx = -4; dx <= 4; dx++) {
        for (let dz = -4; dz <= 4; dz++) {
            const dist = Math.sqrt(dx * dx + dz * dz);

            // Outer ring: stone bricks (radius 3.5-4.5)
            if (dist >= 3.5 && dist <= 4.5) {
                setBlock(dim, { x: base.x + dx, y: baseY, z: base.z + dz }, 'minecraft:stone_bricks');
                setBlock(dim, { x: base.x + dx, y: baseY + 1, z: base.z + dz }, 'minecraft:stone_bricks');
            }

            // Inner ring: prismarine (radius 2.5-3.5)
            if (dist >= 2.5 && dist < 3.5) {
                setBlock(dim, { x: base.x + dx, y: baseY, z: base.z + dz }, 'minecraft:prismarine');
            }

            // Water pool (radius < 3)
            if (dist < 3) {
                // Base with hidden sea lanterns and glowstone
                if ((dx + dz) % 3 === 0) {
                    setBlock(dim, { x: base.x + dx, y: baseY - 1, z: base.z + dz }, 'minecraft:sea_lantern');
                } else {
                    setBlock(dim, { x: base.x + dx, y: baseY - 1, z: base.z + dz }, 'minecraft:glowstone');
                }
                setBlock(dim, { x: base.x + dx, y: baseY, z: base.z + dz }, 'minecraft:water');
            }
        }
    }

    // Center column (stone brick, 3 high, water cascading)
    setBlock(dim, { x: base.x, y: baseY, z: base.z }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x, y: baseY + 1, z: base.z }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x, y: baseY + 2, z: base.z }, 'minecraft:stone_bricks');
    setBlock(dim, { x: base.x, y: baseY + 3, z: base.z }, 'minecraft:water');

    // Gold star pattern at the bottom of the fountain
    const starPoints = [
        { x: 0, z: -2 }, { x: 0, z: 2 }, { x: -2, z: 0 }, { x: 2, z: 0 },
        { x: -1, z: -1 }, { x: 1, z: -1 }, { x: -1, z: 1 }, { x: 1, z: 1 },
    ];
    for (const sp of starPoints) {
        setBlock(dim, { x: base.x + sp.x, y: baseY - 1, z: base.z + sp.z }, 'minecraft:gold_block');
    }

    // Lily pads on the water surface
    const lilyPositions = [
        { x: -2, z: 0 }, { x: 2, z: 0 }, { x: 0, z: -2 }, { x: 0, z: 2 },
        { x: -1, z: 1 }, { x: 1, z: -1 },
    ];
    for (const lp of lilyPositions) {
        setBlock(dim, { x: base.x + lp.x, y: baseY + 1, z: base.z + lp.z }, 'minecraft:lily_pad');
    }

    // Drop a diamond and emerald into the water
    const waterCenter = { x: base.x + 0.5, y: baseY + 1.5, z: base.z + 0.5 };
    try { dim.spawnItem(new ItemStack('minecraft:diamond', 1), waterCenter); } catch (_) {}
    try { dim.spawnItem(new ItemStack('minecraft:emerald', 1), waterCenter); } catch (_) {}

    // Decorative lanterns around the fountain
    for (let i = 0; i < 8; i++) {
        const angle = (i / 8) * Math.PI * 2;
        const lx = Math.floor(base.x + Math.cos(angle) * 5);
        const lz = Math.floor(base.z + Math.sin(angle) * 5);
        setBlock(dim, { x: lx, y: baseY + 1, z: lz }, 'minecraft:oak_fence');
        setBlock(dim, { x: lx, y: baseY + 2, z: lz }, 'minecraft:lantern');
    }

    // Magical sparkle particles
    for (let i = 0; i < 20; i++) {
        const angle = Math.random() * Math.PI * 2;
        const r = Math.random() * 4;
        spawnParticle(dim, 'minecraft:villager_happy', {
            x: base.x + Math.cos(angle) * r,
            y: baseY + 1 + Math.random() * 2,
            z: base.z + Math.sin(angle) * r,
        });
    }
}

// ============================================================
// MAIN TICK DISPATCHER
// ============================================================

/**
 * Called every second from the main tick loop.
 * Checks and triggers all wonder events.
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function tickWonder(player, currentTick) {
    checkFairyVillage(player, currentTick);
    checkSparkleTornado(player, currentTick);
    checkPetParade(player, currentTick);
    checkTreasureHunt(player, currentTick);
    checkCloudKingdom(player, currentTick);
    checkDanceParty(player, currentTick);
    checkLibraryRoom(player, currentTick);
    checkWishingFountain(player, currentTick);
}
