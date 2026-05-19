/**
 * Magical unicorns that visit and build sparkly castles.
 */
import { world, system } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

const UNICORN_MESSAGES = [
    'A magical unicorn appears! It\'s building a castle!',
    'Unicorn magic! A castle just for you!',
    'The unicorn thinks you deserve a castle!',
    'Sparkle sparkle! Castle time!',
    'A unicorn heard about your beautiful world!',
];

const UNICORN_DONE = [
    'The unicorn waves goodbye! Enjoy your castle!',
    'Magical! The unicorn gallops away over the rainbow!',
    'The unicorn leaves sparkles behind!',
];

/** Track last unicorn visit */
const lastVisit = new Map();
const VISIT_INTERVAL = 30000; // ~25 minutes

/**
 * Build a sparkly castle.
 * @param {import('@minecraft/server').Dimension} dim
 * @param {import('@minecraft/server').Vector3} base
 */
function buildCastle(dim, base) {
    const blocks = [];
    const W = 'minecraft:quartz_block';    // white walls
    const P = 'minecraft:pink_glazed_terracotta';  // pink accents
    const G = 'minecraft:glass';
    const S = 'minecraft:quartz_stairs';
    const PURP = 'minecraft:purple_wool';  // purple roof
    const PINK = 'minecraft:pink_wool';    // pink towers
    const GOLD = 'minecraft:gold_block';   // gold trim
    const T = 'minecraft:torch';
    const F = 'minecraft:oak_fence';

    const bx = Math.floor(base.x);
    const by = Math.floor(base.y);
    const bz = Math.floor(base.z);

    // Castle base: 9x9 floor
    for (let x = -4; x <= 4; x++) {
        for (let z = 0; z <= 8; z++) {
            set(dim, bx + x, by, bz + z, W);
        }
    }

    // Walls: 5 high
    for (let y = 1; y <= 5; y++) {
        for (let x = -4; x <= 4; x++) {
            for (let z = 0; z <= 8; z++) {
                const isEdge = x === -4 || x === 4 || z === 0 || z === 8;
                if (!isEdge) continue;

                // Door at front center
                if (z === 0 && x >= -1 && x <= 1 && y <= 3) continue;

                // Windows at y=3
                if (y === 3 && ((x === -4 && z === 4) || (x === 4 && z === 4) ||
                    (z === 8 && (x === -2 || x === 2)))) {
                    set(dim, bx + x, by + y, bz + z, G);
                    continue;
                }

                // Gold trim at y=5
                if (y === 5) {
                    set(dim, bx + x, by + y, bz + z, GOLD);
                    continue;
                }

                set(dim, bx + x, by + y, bz + z, W);
            }
        }
    }

    // Four corner towers (3x3, 8 high)
    const towers = [[-4, 0], [4, 0], [-4, 8], [4, 8]];
    for (const [tx, tz] of towers) {
        for (let y = 1; y <= 8; y++) {
            for (let dx = -1; dx <= 1; dx++) {
                for (let dz = -1; dz <= 1; dz++) {
                    const isEdge = dx === -1 || dx === 1 || dz === -1 || dz === 1;
                    if (!isEdge && y < 8) continue; // hollow inside
                    if (y <= 5) {
                        set(dim, bx + tx + dx, by + y, bz + tz + dz, W);
                    } else {
                        set(dim, bx + tx + dx, by + y, bz + tz + dz, PINK);
                    }
                }
            }
        }
        // Pointy top
        set(dim, bx + tx, by + 9, bz + tz, PURP);
        // Flag (fence + wool)
        set(dim, bx + tx, by + 10, bz + tz, F);
        set(dim, bx + tx, by + 11, bz + tz, PINK);
    }

    // Roof: purple wool pyramid
    for (let layer = 0; layer < 3; layer++) {
        const r = 3 - layer;
        for (let x = -r; x <= r; x++) {
            for (let z = 1; z <= 7; z++) {
                if (z >= 1 + layer && z <= 7 - layer) {
                    set(dim, bx + x, by + 6 + layer, bz + z, PURP);
                }
            }
        }
    }

    // Torches inside
    set(dim, bx - 2, by + 3, bz + 2, T);
    set(dim, bx + 2, by + 3, bz + 2, T);
    set(dim, bx - 2, by + 3, bz + 6, T);
    set(dim, bx + 2, by + 3, bz + 6, T);

    // Carpet path to entrance
    for (let z = -3; z < 0; z++) {
        set(dim, bx - 1, by, bz + z, 'minecraft:pink_carpet');
        set(dim, bx, by, bz + z, 'minecraft:magenta_carpet');
        set(dim, bx + 1, by, bz + z, 'minecraft:pink_carpet');
    }
}

function set(dim, x, y, z, block) {
    try { dim.setBlockType({ x, y, z }, block); } catch (_) {}
}

/**
 * Check if a unicorn should visit.
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function forceUnicornVisit(player) {
    lastVisit.delete(player.name);
    checkUnicornVisit(player, 999999999);
}

export function checkUnicornVisit(player, currentTick) {
    const last = lastVisit.get(player.name) || 0;
    if (currentTick - last < VISIT_INTERVAL) return;

    lastVisit.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;

    // Unicorn announcement
    player.onScreenDisplay.setTitle('A Unicorn Appears!', {
        fadeInDuration: 10,
        stayDuration: 60,
        fadeOutDuration: 10,
        subtitle: randomChoice(UNICORN_MESSAGES),
    });

    // Spawn a real white horse as the unicorn
    let unicorn = null;
    const spawnPos = randomNearby(loc, 15, 20);
    spawnPos.y = Math.floor(loc.y);
    try {
        unicorn = dim.spawnEntity('minecraft:horse', spawnPos);
        unicorn.addTag('little_unicorn_visitor');
        unicorn.nameTag = 'Magical Unicorn';
        // Trigger white variant
        unicorn.triggerEvent('minecraft:ageable_grow_up');
    } catch (_) {}

    // Sparkle trail following the unicorn as it walks toward the build site
    const castlePos = randomNearby(loc, 12, 20);
    castlePos.y = Math.floor(loc.y);

    let step = 0;
    const trail = system.runInterval(() => {
        if (step > 30) {
            system.clearRun(trail);
            return;
        }
        try {
            if (unicorn) {
                const valid = typeof unicorn.isValid === 'function' ? unicorn.isValid() : unicorn.isValid !== false;
                if (valid) {
                    // Move unicorn toward castle site
                    const t = step / 30;
                    const ux = spawnPos.x + (castlePos.x - spawnPos.x) * t;
                    const uz = spawnPos.z + (castlePos.z - spawnPos.z) * t;
                    unicorn.teleport({ x: ux, y: spawnPos.y, z: uz });
                    // Sparkle trail
                    dim.spawnParticle('minecraft:villager_happy', { x: ux, y: spawnPos.y + 2, z: uz });
                    dim.spawnParticle('minecraft:villager_happy', { x: ux + 1, y: spawnPos.y + 1, z: uz + 1 });
                }
            }
        } catch (_) {}
        step++;
    }, 4);

    // Build the castle after the unicorn arrives
    system.runTimeout(() => {
        buildCastle(dim, castlePos);

        // Sparkle burst at castle
        try {
            dim.spawnParticle('minecraft:villager_happy', { x: castlePos.x, y: castlePos.y + 5, z: castlePos.z + 4 });
        } catch (_) {}

        player.onScreenDisplay.setActionBar(randomChoice(UNICORN_DONE));

        // Unicorn hangs around for a bit then disappears
        system.runTimeout(() => {
            try {
                if (unicorn) {
                    dim.spawnParticle('minecraft:large_explosion', unicorn.location);
                    unicorn.kill();
                }
            } catch (_) {}
        }, 200);
    }, 140);
}
