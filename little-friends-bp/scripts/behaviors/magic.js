/**
 * Magical world events for Little Friends add-on.
 * All events are triggered from the main tick loop via tickMagic().
 */
import { world, system } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

// --- Cooldown maps (one per feature, keyed by player name) ---
const fireworksCooldown   = new Map();
const islandCooldown      = new Map();
const butterflyCooldown   = new Map();
const fairyLightsCooldown = new Map();
const crystalCooldown     = new Map();
const mushroomCooldown    = new Map();
const waterfallCooldown   = new Map();
const starCooldown        = new Map();
const rainbowBridgeCooldown  = new Map();
const enchantedPondCooldown  = new Map();
const giantFlowerCooldown    = new Map();
const auroraCooldown         = new Map();
const candyTrailCooldown     = new Map();
const snowGlobeCooldown      = new Map();
const friendlyWhalesCooldown = new Map();
const magicPortalCooldown    = new Map();

// ============================================================
// 1. FIREWORKS AT NIGHT  (every ~30 seconds at night)
// ============================================================
const FIREWORKS_INTERVAL = 600; // ticks

function checkFireworks(player, currentTick) {
    const last = fireworksCooldown.get(player.name) || 0;
    if (currentTick - last < FIREWORKS_INTERVAL) return;

    const timeOfDay = world.getTimeOfDay();
    if (timeOfDay < 13000 || timeOfDay > 23000) return;

    fireworksCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const count = 3 + Math.floor(Math.random() * 3); // 3–5

    for (let i = 0; i < count; i++) {
        const base = randomNearby(loc, 10, 20);
        const launchY = Math.floor(loc.y) + 5 + Math.floor(Math.random() * 11); // 5–15 up
        const launchPos = { x: base.x, y: launchY, z: base.z };

        try {
            dim.spawnEntity('minecraft:fireworks_rocket', launchPos);
        } catch (_) {}

        try {
            dim.spawnParticle('minecraft:villager_happy', {
                x: launchPos.x + 0.5,
                y: launchPos.y + 0.5,
                z: launchPos.z + 0.5,
            });
        } catch (_) {}
    }
}

// ============================================================
// 2. FLOATING ISLANDS  (every ~5 minutes)
// ============================================================
const ISLAND_INTERVAL = 6000; // ticks

const ISLAND_FLOWERS = [
    'minecraft:poppy',
    'minecraft:dandelion',
    'minecraft:blue_orchid',
    'minecraft:cornflower',
];

function checkFloatingIsland(player, currentTick) {
    const last = islandCooldown.get(player.name) || 0;
    if (currentTick - last < ISLAND_INTERVAL) return;

    islandCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const basePos = randomNearby(loc, 15, 30);
    const islandY = Math.floor(loc.y) + 20 + Math.floor(Math.random() * 16); // 20–35 above

    // 5x5 grass base + dirt underneath
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            const grassPos  = { x: basePos.x + dx, y: islandY,     z: basePos.z + dz };
            const dirtPos   = { x: basePos.x + dx, y: islandY - 1, z: basePos.z + dz };
            try { dim.setBlockType(grassPos, 'minecraft:grass_block'); } catch (_) {}
            try { dim.setBlockType(dirtPos,  'minecraft:dirt'); } catch (_) {}
        }
    }

    // Random flowers on grass surface
    const flowerCount = 3 + Math.floor(Math.random() * 4);
    for (let i = 0; i < flowerCount; i++) {
        const fx = basePos.x + Math.floor(Math.random() * 5) - 2;
        const fz = basePos.z + Math.floor(Math.random() * 5) - 2;
        // Skip center (reserved for tree)
        if (Math.abs(fx - basePos.x) < 2 && Math.abs(fz - basePos.z) < 2) continue;
        const flowerPos = { x: fx, y: islandY + 1, z: fz };
        try {
            const block = dim.getBlock(flowerPos);
            if (block && block.typeId === 'minecraft:air') {
                dim.setBlockType(flowerPos, randomChoice(ISLAND_FLOWERS));
            }
        } catch (_) {}
    }

    // 1 oak tree: 4-high trunk + 3x3x2 leaf canopy
    const treeBase = { x: basePos.x, y: islandY + 1, z: basePos.z };
    for (let ty = 0; ty < 4; ty++) {
        try { dim.setBlockType({ x: treeBase.x, y: treeBase.y + ty, z: treeBase.z }, 'minecraft:oak_log'); } catch (_) {}
    }
    const canopyBase = treeBase.y + 4;
    for (let ly = 0; ly < 2; ly++) {
        for (let lx = -1; lx <= 1; lx++) {
            for (let lz = -1; lz <= 1; lz++) {
                const leafPos = { x: treeBase.x + lx, y: canopyBase + ly, z: treeBase.z + lz };
                try {
                    const block = dim.getBlock(leafPos);
                    if (block && block.typeId === 'minecraft:air') {
                        dim.setBlockType(leafPos, 'minecraft:oak_leaves');
                    }
                } catch (_) {}
            }
        }
    }

    // 1–2 lanterns hanging from bottom (y-2 below grass level)
    const lanternCount = 1 + Math.floor(Math.random() * 2);
    const lanternOffsets = [
        { x: -1, z: -1 }, { x: 1, z: -1 }, { x: -1, z: 1 }, { x: 1, z: 1 },
    ];
    for (let i = 0; i < lanternCount; i++) {
        const off = lanternOffsets[i];
        const lanternPos = { x: basePos.x + off.x, y: islandY - 2, z: basePos.z + off.z };
        try { dim.setBlockType(lanternPos, 'minecraft:lantern'); } catch (_) {}
    }
}

// ============================================================
// 3. BUTTERFLIES  (every ~15 seconds)
// ============================================================
const BUTTERFLY_INTERVAL = 300; // ticks

const BUTTERFLY_PARTICLES = [
    'minecraft:heart_particle',
    'minecraft:villager_happy',
    'minecraft:basic_flame_particle',
];

function checkButterflies(player, currentTick) {
    const last = butterflyCooldown.get(player.name) || 0;
    if (currentTick - last < BUTTERFLY_INTERVAL) return;

    butterflyCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = { x: player.location.x, y: player.location.y, z: player.location.z };

    let iteration = 0;
    const interval = system.runInterval(() => {
        if (iteration >= 40) {
            system.clearRun(interval);
            return;
        }

        const spawnCount = 3 + Math.floor(Math.random() * 3); // 3–5
        for (let i = 0; i < spawnCount; i++) {
            const angle = Math.random() * 2 * Math.PI + (iteration * 0.3);
            const radius = 2 + Math.random() * 3; // 2–5 blocks
            const height = 1 + Math.random() * 3; // 1–4 blocks above player
            const flutter = Math.sin(iteration * 0.5 + i) * 0.5;

            const particlePos = {
                x: loc.x + Math.cos(angle) * radius,
                y: loc.y + height + flutter,
                z: loc.z + Math.sin(angle) * radius,
            };

            try {
                dim.spawnParticle(randomChoice(BUTTERFLY_PARTICLES), particlePos);
            } catch (_) {}
        }

        iteration++;
    }, 1); // every tick for ~2 seconds (40 ticks)
}

// ============================================================
// 4. FAIRY LIGHTS IN TREES  (every ~2 minutes)
// ============================================================
const FAIRY_LIGHTS_INTERVAL = 2400; // ticks

function checkFairyLights(player, currentTick) {
    const last = fairyLightsCooldown.get(player.name) || 0;
    if (currentTick - last < FAIRY_LIGHTS_INTERVAL) return;

    fairyLightsCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const radius = 10;
    const lightTypes = ['minecraft:lantern', 'minecraft:sea_lantern'];

    let placed = 0;
    const maxLights = 3 + Math.floor(Math.random() * 3); // 3–5

    for (let dx = -radius; dx <= radius && placed < maxLights; dx++) {
        for (let dz = -radius; dz <= radius && placed < maxLights; dz++) {
            for (let dy = -5; dy <= 10 && placed < maxLights; dy++) {
                const checkPos = {
                    x: Math.floor(loc.x) + dx,
                    y: Math.floor(loc.y) + dy,
                    z: Math.floor(loc.z) + dz,
                };
                const belowPos = { x: checkPos.x, y: checkPos.y - 1, z: checkPos.z };

                try {
                    const block = dim.getBlock(checkPos);
                    const above = dim.getBlock(belowPos); // block below the air gap

                    // Find oak_leaves with air below (hang a light under the leaves)
                    if (block && block.typeId === 'minecraft:oak_leaves') {
                        const airPos = { x: checkPos.x, y: checkPos.y - 1, z: checkPos.z };
                        const airBlock = dim.getBlock(airPos);
                        if (airBlock && airBlock.typeId === 'minecraft:air') {
                            dim.setBlockType(airPos, randomChoice(lightTypes));
                            placed++;
                        }
                    }
                } catch (_) {}
            }
        }
    }
}

// ============================================================
// 5. CRYSTAL CAVES  (every ~8 minutes)
// ============================================================
const CRYSTAL_INTERVAL = 9600; // ticks

function checkCrystalCave(player, currentTick) {
    const last = crystalCooldown.get(player.name) || 0;
    if (currentTick - last < CRYSTAL_INTERVAL) return;

    crystalCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const depth = 10 + Math.floor(Math.random() * 6); // 10–15 below
    const cx = Math.floor(loc.x);
    const cy = Math.floor(loc.y) - depth;
    const cz = Math.floor(loc.z);

    // Clear interior to air first (5x5x4 room)
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            for (let dy = 0; dy < 4; dy++) {
                try { dim.setBlockType({ x: cx + dx, y: cy + dy, z: cz + dz }, 'minecraft:air'); } catch (_) {}
            }
        }
    }

    // Walls: amethyst_block
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            for (let dy = 0; dy < 4; dy++) {
                const isEdge = Math.abs(dx) === 2 || Math.abs(dz) === 2 || dy === 0 || dy === 3;
                if (!isEdge) continue;
                try {
                    dim.setBlockType({ x: cx + dx, y: cy + dy, z: cz + dz }, 'minecraft:amethyst_block');
                } catch (_) {}
            }
        }
    }

    // Floor: mix of amethyst_block and budding_amethyst
    for (let dx = -1; dx <= 1; dx++) {
        for (let dz = -1; dz <= 1; dz++) {
            const block = Math.random() > 0.5 ? 'minecraft:budding_amethyst' : 'minecraft:amethyst_block';
            try { dim.setBlockType({ x: cx + dx, y: cy, z: cz + dz }, block); } catch (_) {}
        }
    }

    // Ceiling: alternating glowstone and amethyst_block
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            const block = (dx + dz) % 2 === 0 ? 'minecraft:glowstone' : 'minecraft:amethyst_block';
            try { dim.setBlockType({ x: cx + dx, y: cy + 3, z: cz + dz }, block); } catch (_) {}
        }
    }

    // 2–3 amethyst clusters on walls (random wall positions at mid-height)
    const wallSpots = [
        { x: cx - 2, y: cy + 1, z: cz },
        { x: cx + 2, y: cy + 1, z: cz },
        { x: cx,     y: cy + 1, z: cz - 2 },
        { x: cx,     y: cy + 1, z: cz + 2 },
    ];
    const clusterCount = 2 + Math.floor(Math.random() * 2);
    for (let i = 0; i < clusterCount; i++) {
        const spot = wallSpots[i];
        try { dim.setBlockType(spot, 'minecraft:amethyst_cluster'); } catch (_) {}
    }

    // Small 2x2 water pool in one corner
    const corners = [
        { x: cx - 1, z: cz - 1 },
        { x: cx + 1, z: cz - 1 },
        { x: cx - 1, z: cz + 1 },
        { x: cx + 1, z: cz + 1 },
    ];
    const corner = randomChoice(corners);
    for (let dx = 0; dx <= 1; dx++) {
        for (let dz = 0; dz <= 1; dz++) {
            try { dim.setBlockType({ x: corner.x + dx, y: cy + 1, z: corner.z + dz }, 'minecraft:water'); } catch (_) {}
        }
    }

    // Lantern in the center
    try { dim.setBlockType({ x: cx, y: cy + 1, z: cz }, 'minecraft:lantern'); } catch (_) {}
}

// ============================================================
// 6. MAGIC MUSHROOM CIRCLES  (every ~4 minutes)
// ============================================================
const MUSHROOM_INTERVAL = 4800; // ticks

const RING_WOOLS = ['minecraft:red_wool', 'minecraft:orange_wool', 'minecraft:yellow_wool', 'minecraft:lime_wool'];

function checkMushroomCircle(player, currentTick) {
    const last = mushroomCooldown.get(player.name) || 0;
    if (currentTick - last < MUSHROOM_INTERVAL) return;

    mushroomCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const cx = Math.floor(loc.x);
    const cy = Math.floor(loc.y);
    const cz = Math.floor(loc.z);

    // Check that we're on grass/dirt before placing
    try {
        const ground = dim.getBlock({ x: cx, y: cy - 1, z: cz });
        if (!ground || (ground.typeId !== 'minecraft:grass_block' && ground.typeId !== 'minecraft:dirt')) return;
    } catch (_) { return; }

    // 8 mushrooms at radius 4, alternating red/brown
    const radius = 4;
    const mushrooms = ['minecraft:red_mushroom', 'minecraft:brown_mushroom'];
    for (let i = 0; i < 8; i++) {
        const angle = (i / 8) * 2 * Math.PI;
        const mx = Math.round(cx + Math.cos(angle) * radius);
        const mz = Math.round(cz + Math.sin(angle) * radius);
        const mushroomPos = { x: mx, y: cy, z: mz };

        try {
            const below = dim.getBlock({ x: mx, y: cy - 1, z: mz });
            const slot  = dim.getBlock(mushroomPos);
            if (below && slot &&
                (below.typeId === 'minecraft:grass_block' || below.typeId === 'minecraft:dirt') &&
                slot.typeId === 'minecraft:air') {
                dim.setBlockType(mushroomPos, mushrooms[i % 2]);
            }
        } catch (_) {}
    }

    // Glowing center: glowstone buried at y-1, glass on top
    try { dim.setBlockType({ x: cx, y: cy - 1, z: cz }, 'minecraft:glowstone'); } catch (_) {}
    try { dim.setBlockType({ x: cx, y: cy,     z: cz }, 'minecraft:glass'); } catch (_) {}

    // Ring of colored wool inside the mushroom circle (radius ~2)
    let woolIdx = 0;
    for (let i = 0; i < 4; i++) {
        const angle = (i / 4) * 2 * Math.PI;
        const wx = Math.round(cx + Math.cos(angle) * 2);
        const wz = Math.round(cz + Math.sin(angle) * 2);
        try {
            const below = dim.getBlock({ x: wx, y: cy - 1, z: wz });
            const slot  = dim.getBlock({ x: wx, y: cy, z: wz });
            if (below && slot &&
                (below.typeId === 'minecraft:grass_block' || below.typeId === 'minecraft:dirt') &&
                slot.typeId === 'minecraft:air') {
                dim.setBlockType({ x: wx, y: cy, z: wz }, RING_WOOLS[woolIdx % RING_WOOLS.length]);
                woolIdx++;
            }
        } catch (_) {}
    }

    // Particles at center
    try {
        dim.spawnParticle('minecraft:villager_happy', { x: cx + 0.5, y: cy + 0.5, z: cz + 0.5 });
    } catch (_) {}
}

// ============================================================
// 7. WATERFALLS  (every ~6 minutes)
// ============================================================
const WATERFALL_INTERVAL = 7200; // ticks

function checkWaterfall(player, currentTick) {
    const last = waterfallCooldown.get(player.name) || 0;
    if (currentTick - last < WATERFALL_INTERVAL) return;

    waterfallCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 10, 20);
    const fallHeight = 8 + Math.floor(Math.random() * 5); // 8–12 blocks
    const topY = Math.floor(loc.y) + fallHeight;
    const bx = base.x;
    const bz = base.z;

    // Glowstone column behind the water (z-1)
    for (let dy = 0; dy <= fallHeight; dy++) {
        try { dim.setBlockType({ x: bx, y: Math.floor(loc.y) + dy, z: bz - 1 }, 'minecraft:glowstone'); } catch (_) {}
    }

    // Water column
    for (let dy = 0; dy <= fallHeight; dy++) {
        try { dim.setBlockType({ x: bx, y: Math.floor(loc.y) + dy, z: bz }, 'minecraft:water'); } catch (_) {}
    }

    // Stone brick frame on sides
    for (let dy = 0; dy <= fallHeight; dy++) {
        try { dim.setBlockType({ x: bx - 1, y: Math.floor(loc.y) + dy, z: bz }, 'minecraft:stone_bricks'); } catch (_) {}
        try { dim.setBlockType({ x: bx + 1, y: Math.floor(loc.y) + dy, z: bz }, 'minecraft:stone_bricks'); } catch (_) {}
    }

    // 3x3 water pool at base
    for (let dx = -1; dx <= 1; dx++) {
        for (let dz = -1; dz <= 1; dz++) {
            try { dim.setBlockType({ x: bx + dx, y: Math.floor(loc.y), z: bz + dz }, 'minecraft:water'); } catch (_) {}
        }
    }

    // Top cap stone bricks
    try { dim.setBlockType({ x: bx - 1, y: topY + 1, z: bz }, 'minecraft:stone_bricks'); } catch (_) {}
    try { dim.setBlockType({ x: bx + 1, y: topY + 1, z: bz }, 'minecraft:stone_bricks'); } catch (_) {}
}

// ============================================================
// 8. STAR PATTERNS  (every ~3 minutes, night only)
// ============================================================
const STAR_INTERVAL = 3600; // ticks

const STAR_SHAPES = ['cross', 'diamond', 'line'];

function checkStarPatterns(player, currentTick) {
    const last = starCooldown.get(player.name) || 0;
    if (currentTick - last < STAR_INTERVAL) return;

    const timeOfDay = world.getTimeOfDay();
    if (timeOfDay < 13000 && timeOfDay > 500) return;

    starCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const offset = randomNearby(loc, 10, 20);
    const starY = Math.floor(loc.y) + 30 + Math.floor(Math.random() * 11); // 30–40 above

    const shape = randomChoice(STAR_SHAPES);
    const sx = offset.x;
    const sz = offset.z;

    let positions = [];
    if (shape === 'cross') {
        positions = [
            { x: sx,     y: starY, z: sz },
            { x: sx - 1, y: starY, z: sz },
            { x: sx + 1, y: starY, z: sz },
            { x: sx,     y: starY, z: sz - 1 },
            { x: sx,     y: starY, z: sz + 1 },
        ];
    } else if (shape === 'diamond') {
        positions = [
            { x: sx,     y: starY, z: sz },
            { x: sx - 1, y: starY, z: sz },
            { x: sx + 1, y: starY, z: sz },
            { x: sx,     y: starY, z: sz - 1 },
            { x: sx,     y: starY, z: sz + 1 },
            { x: sx - 2, y: starY, z: sz },
            { x: sx + 2, y: starY, z: sz },
        ];
    } else { // line
        const count = 3 + Math.floor(Math.random() * 3); // 3–5
        for (let i = 0; i < count; i++) {
            positions.push({ x: sx + i - Math.floor(count / 2), y: starY, z: sz });
        }
    }

    for (const pos of positions) {
        try { dim.setBlockType(pos, 'minecraft:glowstone'); } catch (_) {}
    }
}

// ============================================================
// 9. RAINBOW BRIDGE  (every ~5 minutes)
// ============================================================
const RAINBOW_BRIDGE_INTERVAL = 6000; // ticks

const BRIDGE_GLASS = [
    'minecraft:red_stained_glass',
    'minecraft:orange_stained_glass',
    'minecraft:yellow_stained_glass',
    'minecraft:lime_stained_glass',
    'minecraft:cyan_stained_glass',
    'minecraft:blue_stained_glass',
    'minecraft:purple_stained_glass',
];

function checkRainbowBridge(player, currentTick) {
    const last = rainbowBridgeCooldown.get(player.name) || 0;
    if (currentTick - last < RAINBOW_BRIDGE_INTERVAL) return;

    rainbowBridgeCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const startX = Math.floor(loc.x) + 3;
    const baseY  = Math.floor(loc.y);
    const startZ = Math.floor(loc.z);
    const bridgeLength = 20; // total horizontal span
    const peakHeight   = 8;  // max arch height

    // 7 lanes (one per color), each offset on Z
    for (let lane = 0; lane < 7; lane++) {
        const glass = BRIDGE_GLASS[lane];
        const lz    = startZ + lane - 3; // center the bridge on Z

        for (let step = 0; step <= bridgeLength; step++) {
            // Half-circle arch: y = peakHeight * sin(pi * step / bridgeLength)
            const archY = Math.round(baseY + peakHeight * Math.sin(Math.PI * step / bridgeLength));
            const bx    = startX + step;

            try { dim.setBlockType({ x: bx, y: archY, z: lz }, glass); } catch (_) {}

            // Fence railing on outermost lanes
            if (lane === 0 || lane === 6) {
                try { dim.setBlockType({ x: bx, y: archY + 1, z: lz }, 'minecraft:oak_fence'); } catch (_) {}
            }
        }
    }
}

// ============================================================
// 10. ENCHANTED POND  (every ~7 minutes)
// ============================================================
const ENCHANTED_POND_INTERVAL = 8400; // ticks

function checkEnchantedPond(player, currentTick) {
    const last = enchantedPondCooldown.get(player.name) || 0;
    if (currentTick - last < ENCHANTED_POND_INTERVAL) return;

    enchantedPondCooldown.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;
    const base = randomNearby(loc, 8, 15);
    const cx   = base.x;
    const cz   = base.z;
    const groundY = Math.floor(loc.y);
    const pondY   = groundY - 1; // dig 1 down

    // 5x5 circular pond (circle of radius ~2)
    const pondCells = [];
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            if (dx * dx + dz * dz <= 6) { // roughly circular
                pondCells.push({ dx, dz });
            }
        }
    }

    // Dig and fill with water
    for (const { dx, dz } of pondCells) {
        try { dim.setBlockType({ x: cx + dx, y: pondY,      z: cz + dz }, 'minecraft:water'); } catch (_) {}
        try { dim.setBlockType({ x: cx + dx, y: pondY - 1,  z: cz + dz }, 'minecraft:dirt'); }  catch (_) {}
    }

    // Rim: prismarine with sea_lantern every other block
    let rimIdx = 0;
    for (let dx = -3; dx <= 3; dx++) {
        for (let dz = -3; dz <= 3; dz++) {
            const dist = Math.sqrt(dx * dx + dz * dz);
            if (dist < 2.5 || dist > 3.5) continue;
            const rimBlock = (rimIdx % 2 === 0) ? 'minecraft:prismarine' : 'minecraft:sea_lantern';
            try { dim.setBlockType({ x: cx + dx, y: groundY, z: cz + dz }, rimBlock); } catch (_) {}
            rimIdx++;
        }
    }

    // Lily pads on water surface
    const lilySpots = [{ dx: 1, dz: 0 }, { dx: -1, dz: 0 }, { dx: 0, dz: 1 }, { dx: 0, dz: -1 }];
    for (const { dx, dz } of lilySpots) {
        try { dim.setBlockType({ x: cx + dx, y: groundY, z: cz + dz }, 'minecraft:waterlily'); } catch (_) {}
    }

    // Sea lantern in center underwater
    try { dim.setBlockType({ x: cx, y: pondY - 1, z: cz }, 'minecraft:sea_lantern'); } catch (_) {}

    // Sparkle particles
    try { dim.spawnParticle('minecraft:villager_happy', { x: cx + 0.5, y: groundY + 0.5, z: cz + 0.5 }); } catch (_) {}
    try { dim.spawnParticle('minecraft:heart_particle',  { x: cx - 0.5, y: groundY + 1,  z: cz + 0.5 }); } catch (_) {}
}

// ============================================================
// 11. GIANT FLOWER  (every ~4 minutes)
// ============================================================
const GIANT_FLOWER_INTERVAL = 4800; // ticks

function checkGiantFlower(player, currentTick) {
    const last = giantFlowerCooldown.get(player.name) || 0;
    if (currentTick - last < GIANT_FLOWER_INTERVAL) return;

    giantFlowerCooldown.set(player.name, currentTick);

    const dim   = player.dimension;
    const loc   = player.location;
    const base  = randomNearby(loc, 8, 18);
    const bx    = base.x;
    const baseY = Math.floor(loc.y);
    const bz    = base.z;

    // 6-block tall green stem
    for (let dy = 0; dy < 6; dy++) {
        try { dim.setBlockType({ x: bx, y: baseY + dy, z: bz }, 'minecraft:green_wool'); } catch (_) {}
    }

    // Leaves at y=2 and y=4: 2 blocks out each side on X and Z
    for (const leafY of [2, 4]) {
        for (let d = 1; d <= 2; d++) {
            try { dim.setBlockType({ x: bx + d, y: baseY + leafY, z: bz }, 'minecraft:green_wool'); } catch (_) {}
            try { dim.setBlockType({ x: bx - d, y: baseY + leafY, z: bz }, 'minecraft:green_wool'); } catch (_) {}
        }
    }

    // 5x5 petal top at y=6 and y=7 using pink/magenta/red wool, center gold
    const petalY = baseY + 6;
    const petalColors = [
        'minecraft:pink_wool',
        'minecraft:magenta_wool',
        'minecraft:red_wool',
    ];
    let colorIdx = 0;
    for (let dx = -2; dx <= 2; dx++) {
        for (let dz = -2; dz <= 2; dz++) {
            const dist = Math.abs(dx) + Math.abs(dz);
            if (dist === 0) {
                // Center: gold block at top of stem
                try { dim.setBlockType({ x: bx, y: petalY, z: bz }, 'minecraft:gold_block'); } catch (_) {}
            } else if (dist <= 4) {
                // Petals: ring of colors
                const petal = petalColors[colorIdx % petalColors.length];
                try { dim.setBlockType({ x: bx + dx, y: petalY, z: bz + dz }, petal); } catch (_) {}
                colorIdx++;
            }
        }
    }
}

// ============================================================
// 12. AURORA BOREALIS  (every ~2 minutes, night only)
// ============================================================
const AURORA_INTERVAL = 2400; // ticks

const AURORA_GLASS = [
    'minecraft:lime_stained_glass',
    'minecraft:light_blue_stained_glass',
    'minecraft:cyan_stained_glass',
    'minecraft:blue_stained_glass',
    'minecraft:purple_stained_glass',
];

function checkAurora(player, currentTick) {
    const last = auroraCooldown.get(player.name) || 0;
    if (currentTick - last < AURORA_INTERVAL) return;

    const timeOfDay = world.getTimeOfDay();
    if (timeOfDay >= 500 && timeOfDay < 13000) return; // day — skip

    auroraCooldown.set(player.name, currentTick);

    const dim  = player.dimension;
    const loc  = player.location;
    const px   = Math.floor(loc.x);
    const pz   = Math.floor(loc.z);
    const baseY = Math.floor(loc.y) + 40;

    // 3-4 bands, each offset in Y and Z
    const bandCount = 3 + Math.floor(Math.random() * 2);
    for (let band = 0; band < bandCount; band++) {
        const glass    = AURORA_GLASS[band % AURORA_GLASS.length];
        const bandY    = baseY + band * 3;
        const zOffset  = (band - Math.floor(bandCount / 2)) * 4;
        const bandLen  = 15 + Math.floor(Math.random() * 6); // 15-20

        for (let step = 0; step < bandLen; step++) {
            // Slight wave on Y using sin
            const waveY = bandY + Math.round(Math.sin(step * 0.4) * 2);
            const bx    = px - Math.floor(bandLen / 2) + step;
            try { dim.setBlockType({ x: bx, y: waveY, z: pz + zOffset }, glass); } catch (_) {}
        }
    }
}

// ============================================================
// 13. CANDY TRAIL  (every ~3 minutes)
// ============================================================
const CANDY_TRAIL_INTERVAL = 3600; // ticks

const CANDY_COLORS = [
    'minecraft:red_wool',
    'minecraft:orange_wool',
    'minecraft:yellow_wool',
    'minecraft:lime_wool',
    'minecraft:light_blue_wool',
    'minecraft:blue_wool',
    'minecraft:purple_wool',
    'minecraft:pink_wool',
];

function checkCandyTrail(player, currentTick) {
    const last = candyTrailCooldown.get(player.name) || 0;
    if (currentTick - last < CANDY_TRAIL_INTERVAL) return;

    candyTrailCooldown.set(player.name, currentTick);

    const dim   = player.dimension;
    const loc   = player.location;
    const trailLen = 15 + Math.floor(Math.random() * 6); // 15-20 blocks
    const groundY  = Math.floor(loc.y);

    let cx = Math.floor(loc.x) + 3;
    let cz = Math.floor(loc.z);
    // Direction starts along X, winds with slight turns
    let dx = 1;
    let dz = 0;

    for (let i = 0; i < trailLen; i++) {
        const color = CANDY_COLORS[i % CANDY_COLORS.length];
        try { dim.setBlockType({ x: cx, y: groundY, z: cz }, color); } catch (_) {}

        // Occasionally place cake on path (every ~5 blocks)
        if (i > 0 && i % 5 === 0) {
            try { dim.setBlockType({ x: cx, y: groundY + 1, z: cz }, 'minecraft:cake'); } catch (_) {}
        }

        // Random slight turn: -1, 0, or +1 on the perpendicular axis
        const turn = Math.floor(Math.random() * 3) - 1; // -1, 0, 1
        if (dx !== 0) {
            // Moving along X — turn adjusts Z
            cz += turn;
            cx += dx;
        } else {
            // Moving along Z — turn adjusts X
            cx += turn;
            cz += dz;
        }

        // Occasionally swap dominant axis to create winding
        if (Math.random() < 0.15) {
            [dx, dz] = dz === 0 ? [0, 1] : [1, 0];
        }
    }
}

// ============================================================
// 14. SNOW GLOBE  (every ~10 minutes)
// ============================================================
const SNOW_GLOBE_INTERVAL = 12000; // ticks

function checkSnowGlobe(player, currentTick) {
    const last = snowGlobeCooldown.get(player.name) || 0;
    if (currentTick - last < SNOW_GLOBE_INTERVAL) return;

    snowGlobeCooldown.set(player.name, currentTick);

    const dim   = player.dimension;
    const loc   = player.location;
    const base  = randomNearby(loc, 15, 25);
    const cx    = base.x;
    const baseY = Math.floor(loc.y);
    const cz    = base.z;
    const radius = 8;

    // Build glass dome (sphere shell)
    for (let dx = -radius; dx <= radius; dx++) {
        for (let dy = 0; dy <= radius; dy++) {
            for (let dz = -radius; dz <= radius; dz++) {
                const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
                if (dist >= radius - 0.5 && dist <= radius + 0.5) {
                    try {
                        dim.setBlockType({ x: cx + dx, y: baseY + dy, z: cz + dz }, 'minecraft:glass');
                    } catch (_) {}
                }
            }
        }
    }

    // Snow layers on ground inside
    for (let dx = -(radius - 1); dx <= radius - 1; dx++) {
        for (let dz = -(radius - 1); dz <= radius - 1; dz++) {
            if (dx * dx + dz * dz < (radius - 1) * (radius - 1)) {
                try {
                    dim.setBlockType({ x: cx + dx, y: baseY, z: cz + dz }, 'minecraft:snow_layer');
                } catch (_) {}
            }
        }
    }

    // Small spruce tree inside: 4-block trunk + leaf layers
    for (let ty = 1; ty <= 4; ty++) {
        try { dim.setBlockType({ x: cx, y: baseY + ty, z: cz }, 'minecraft:spruce_log'); } catch (_) {}
    }
    // Cone-shaped leaves (wider at bottom, narrower at top)
    const leafLayers = [
        { y: 3, r: 2 },
        { y: 4, r: 2 },
        { y: 5, r: 1 },
        { y: 6, r: 0 }, // just tip
    ];
    for (const { y, r } of leafLayers) {
        for (let lx = -r; lx <= r; lx++) {
            for (let lz = -r; lz <= r; lz++) {
                if (lx * lx + lz * lz <= r * r + 1) {
                    try {
                        dim.setBlockType({ x: cx + lx, y: baseY + y, z: cz + lz }, 'minecraft:spruce_leaves');
                    } catch (_) {}
                }
            }
        }
    }

    // Glowstone at base around tree for warmth glow
    const glowSpots = [
        { dx: 2, dz: 0 }, { dx: -2, dz: 0 }, { dx: 0, dz: 2 }, { dx: 0, dz: -2 },
    ];
    for (const { dx, dz } of glowSpots) {
        try { dim.setBlockType({ x: cx + dx, y: baseY + 1, z: cz + dz }, 'minecraft:glowstone'); } catch (_) {}
    }
}

// ============================================================
// 15. FRIENDLY WHALES  (every ~5 minutes)
// ============================================================
const FRIENDLY_WHALES_INTERVAL = 6000; // ticks

function checkFriendlyWhales(player, currentTick) {
    const last = friendlyWhalesCooldown.get(player.name) || 0;
    if (currentTick - last < FRIENDLY_WHALES_INTERVAL) return;

    friendlyWhalesCooldown.set(player.name, currentTick);

    const dim   = player.dimension;
    const loc   = player.location;
    const px    = Math.floor(loc.x);
    const py    = Math.floor(loc.y);
    const pz    = Math.floor(loc.z);
    const skyY  = py + 20 + Math.floor(Math.random() * 11); // 20-30 up
    const count = 2 + Math.floor(Math.random() * 2); // 2-3

    const dolphins = [];
    for (let i = 0; i < count; i++) {
        const startX = px - 20;
        const startZ = pz + (i - 1) * 3; // spread them out on Z
        try {
            const dolphin = dim.spawnEntity('minecraft:dolphin', { x: startX, y: skyY, z: startZ });
            dolphins.push(dolphin);
        } catch (_) {}
    }

    // Move dolphins across the sky, leaving a particle trail, then remove
    let step = 0;
    const totalSteps = 40;
    const intervalId = system.runInterval(() => {
        if (step >= totalSteps) {
            system.clearRun(intervalId);
            // Remove dolphins
            for (const d of dolphins) {
                try { d.remove(); } catch (_) {}
            }
            // Drop coral and fish items where they passed
            const endX = px + 20;
            for (let fi = 0; fi < 5; fi++) {
                const fx = endX - fi * 3;
                const coralTypes = ['minecraft:brain_coral_block', 'minecraft:tube_coral_block', 'minecraft:bubble_coral_block'];
                try {
                    dim.setBlockType({ x: fx, y: Math.floor(loc.y), z: pz }, coralTypes[fi % coralTypes.length]);
                } catch (_) {}
            }
            return;
        }

        const progress = step / totalSteps;
        const currentX = px - 20 + Math.round(progress * 40);

        for (let i = 0; i < dolphins.length; i++) {
            const dz = pz + (i - 1) * 3;
            try {
                dolphins[i].teleport({ x: currentX, y: skyY + Math.sin(progress * Math.PI * 2) * 2, z: dz });
            } catch (_) {}

            // Particle trail
            try {
                dim.spawnParticle('minecraft:heart_particle', { x: currentX + 0.5, y: skyY - 1, z: dz + 0.5 });
            } catch (_) {}
            if (step % 3 === 0) {
                try {
                    dim.spawnParticle('minecraft:water_splash_particle', { x: currentX + 0.5, y: skyY - 0.5, z: dz + 0.5 });
                } catch (_) {}
            }
        }

        step++;
    }, 5); // every 5 ticks — slow and gentle
}

// ============================================================
// 16. MAGIC PORTAL  (every ~8 minutes)
// ============================================================
const MAGIC_PORTAL_INTERVAL = 9600; // ticks

function checkMagicPortal(player, currentTick) {
    const last = magicPortalCooldown.get(player.name) || 0;
    if (currentTick - last < MAGIC_PORTAL_INTERVAL) return;

    magicPortalCooldown.set(player.name, currentTick);

    const dim   = player.dimension;
    const loc   = player.location;
    const base  = randomNearby(loc, 8, 16);
    const bx    = base.x;
    const baseY = Math.floor(loc.y);
    const bz    = base.z;

    // Archway: 5 tall, 3 wide — frame of crying_obsidian and end_stone
    // Columns at x and x+2 (width=3 including interior at x+1)
    const frameBlocks = ['minecraft:crying_obsidian', 'minecraft:end_stone'];
    for (let dy = 0; dy < 5; dy++) {
        const fb = (dy % 2 === 0) ? frameBlocks[0] : frameBlocks[1];
        try { dim.setBlockType({ x: bx,     y: baseY + dy, z: bz }, fb); } catch (_) {}
        try { dim.setBlockType({ x: bx + 2, y: baseY + dy, z: bz }, fb); } catch (_) {}
    }

    // Top lintel (5 tall arch top = y+5)
    for (let ddx = 0; ddx <= 2; ddx++) {
        const fb = (ddx % 2 === 0) ? frameBlocks[0] : frameBlocks[1];
        try { dim.setBlockType({ x: bx + ddx, y: baseY + 5, z: bz }, fb); } catch (_) {}
    }

    // Glowstone at top center
    try { dim.setBlockType({ x: bx + 1, y: baseY + 5, z: bz }, 'minecraft:glowstone'); } catch (_) {}

    // Interior purple stained glass (x+1, y=0..4)
    for (let dy = 0; dy < 5; dy++) {
        try { dim.setBlockType({ x: bx + 1, y: baseY + dy, z: bz }, 'minecraft:purple_stained_glass'); } catch (_) {}
    }

    // Soul torches on sides at y+1
    try { dim.setBlockType({ x: bx - 1, y: baseY + 1, z: bz }, 'minecraft:soul_torch'); } catch (_) {}
    try { dim.setBlockType({ x: bx + 3, y: baseY + 1, z: bz }, 'minecraft:soul_torch'); } catch (_) {}

    // Dragon breath particles at portal face
    for (let dy = 1; dy <= 4; dy++) {
        try {
            dim.spawnParticle('minecraft:dragon_breath_trail', { x: bx + 1 + 0.5, y: baseY + dy, z: bz + 0.5 });
        } catch (_) {}
    }
}

// ============================================================
// MAIN EXPORT
// ============================================================

/**
 * Tick all magical world events. Called once per second (every 20 ticks).
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function tickMagic(player, currentTick) {
    checkFireworks(player, currentTick);
    checkFloatingIsland(player, currentTick);
    checkButterflies(player, currentTick);
    checkFairyLights(player, currentTick);
    checkCrystalCave(player, currentTick);
    checkMushroomCircle(player, currentTick);
    checkWaterfall(player, currentTick);
    checkStarPatterns(player, currentTick);
    checkRainbowBridge(player, currentTick);
    checkEnchantedPond(player, currentTick);
    checkGiantFlower(player, currentTick);
    checkAurora(player, currentTick);
    checkCandyTrail(player, currentTick);
    checkSnowGlobe(player, currentTick);
    checkFriendlyWhales(player, currentTick);
    checkMagicPortal(player, currentTick);
}
