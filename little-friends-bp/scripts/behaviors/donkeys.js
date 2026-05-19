/**
 * Magical tidy donkeys that appear in packs and clean up the area.
 * They organize blocks, clear debris, flatten terrain, and add paths.
 */
import { world, system } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

const DONKEY_MESSAGES = [
    'The Tidy Donkeys are here!',
    'Cleanup crew reporting for duty!',
    'Time to make everything neat!',
    'The donkeys love a tidy world!',
];

const DONE_MESSAGES = [
    'All tidy! The donkeys trot away happily!',
    'Clean and neat! See you next time!',
    'The Tidy Donkeys wave goodbye!',
];

const lastVisit = new Map();
const VISIT_INTERVAL = 18000; // ~15 minutes

/**
 * Check if tidy donkeys should visit.
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function forceDonkeyVisit(player) {
    lastVisit.delete(player.name);
    checkDonkeyVisit(player, 999999999);
}

export function checkDonkeyVisit(player, currentTick) {
    const last = lastVisit.get(player.name) || 0;
    if (currentTick - last < VISIT_INTERVAL) return;

    lastVisit.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;

    // Announcement
    player.onScreenDisplay.setTitle('The Tidy Donkeys Arrive!', {
        fadeInDuration: 10,
        stayDuration: 60,
        fadeOutDuration: 10,
        subtitle: randomChoice(DONKEY_MESSAGES),
    });

    // Spawn 4-6 donkeys in a pack
    const donkeys = [];
    const count = 4 + Math.floor(Math.random() * 3);
    const names = ['Dusty', 'Mopsy', 'Broom', 'Sparkle', 'Tidy', 'Neat'];
    for (let i = 0; i < count; i++) {
        try {
            const pos = randomNearby(loc, 8, 15);
            pos.y = Math.floor(loc.y);
            const donkey = dim.spawnEntity('minecraft:donkey', pos);
            donkey.addTag('little_tidy_donkey');
            donkey.nameTag = names[i % names.length];
            donkeys.push(donkey);
        } catch (_) {}
    }

    // Tidy up the area over time
    let tidyStep = 0;
    const tidyInterval = system.runInterval(() => {
        if (tidyStep > 60) {
            system.clearRun(tidyInterval);
            // Goodbye
            player.onScreenDisplay.setActionBar(randomChoice(DONE_MESSAGES));
            // Remove donkeys with sparkle
            system.runTimeout(() => {
                for (const d of donkeys) {
                    try {
                        const valid = typeof d.isValid === 'function' ? d.isValid() : d.isValid !== false;
                        if (valid) {
                            dim.spawnParticle('minecraft:villager_happy', d.location);
                            d.kill();
                        }
                    } catch (_) {}
                }
            }, 60);
            return;
        }

        // Each tick: do one tidy action
        try {
            tidyAction(dim, loc, tidyStep);
        } catch (_) {}

        // Move donkeys around to look busy
        for (const d of donkeys) {
            try {
                const valid = typeof d.isValid === 'function' ? d.isValid() : d.isValid !== false;
                if (valid && tidyStep % 5 === 0) {
                    const newPos = randomNearby(loc, 3, 10);
                    newPos.y = Math.floor(loc.y);
                    d.teleport(newPos);
                    dim.spawnParticle('minecraft:villager_happy', {
                        x: newPos.x, y: newPos.y + 1, z: newPos.z
                    });
                }
            } catch (_) {}
        }

        tidyStep++;
    }, 10);
}

/**
 * Perform a single tidy action in the area.
 */
function tidyAction(dim, center, step) {
    const bx = Math.floor(center.x);
    const by = Math.floor(center.y);
    const bz = Math.floor(center.z);
    const radius = 12;

    // Pick a random spot in the area
    const rx = bx + Math.floor(Math.random() * radius * 2) - radius;
    const rz = bz + Math.floor(Math.random() * radius * 2) - radius;

    // Different tidy actions based on step
    const action = step % 5;

    if (action === 0) {
        // Fill random holes (air blocks with solid on all sides)
        for (let dy = -2; dy <= 0; dy++) {
            const pos = { x: rx, y: by + dy, z: rz };
            try {
                const block = dim.getBlock(pos);
                if (block && block.typeId === 'minecraft:air') {
                    const above = dim.getBlock({ x: rx, y: by + dy + 1, z: rz });
                    const below = dim.getBlock({ x: rx, y: by + dy - 1, z: rz });
                    if (below && below.typeId !== 'minecraft:air' && above && above.typeId !== 'minecraft:air') {
                        dim.setBlockType(pos, below.typeId);
                    }
                }
            } catch (_) {}
        }
    } else if (action === 1) {
        // Add path blocks on grass near existing paths/builds
        const pos = { x: rx, y: by, z: rz };
        try {
            const block = dim.getBlock(pos);
            const below = dim.getBlock({ x: rx, y: by - 1, z: rz });
            if (block && block.typeId === 'minecraft:air' && below &&
                (below.typeId === 'minecraft:grass_block' || below.typeId === 'minecraft:dirt')) {
                // Check if near a build (any non-natural block nearby)
                const neighbor = dim.getBlock({ x: rx + 1, y: by, z: rz });
                const neighbor2 = dim.getBlock({ x: rx, y: by, z: rz + 1 });
                if ((neighbor && neighbor.typeId === 'minecraft:oak_planks') ||
                    (neighbor2 && neighbor2.typeId === 'minecraft:cobblestone')) {
                    dim.setBlockType({ x: rx, y: by - 1, z: rz }, 'minecraft:grass_path');
                }
            }
        } catch (_) {}
    } else if (action === 2) {
        // Place torches in dark spots (air blocks at ground level)
        const pos = { x: rx, y: by + 1, z: rz };
        try {
            const block = dim.getBlock(pos);
            const below = dim.getBlock({ x: rx, y: by, z: rz });
            if (block && block.typeId === 'minecraft:air' && below &&
                below.typeId !== 'minecraft:air' && below.typeId !== 'minecraft:water') {
                // Only place torch if no other torch within 5 blocks
                let hasTorch = false;
                for (let dx = -3; dx <= 3 && !hasTorch; dx++) {
                    for (let dz = -3; dz <= 3 && !hasTorch; dz++) {
                        try {
                            const check = dim.getBlock({ x: rx + dx, y: by + 1, z: rz + dz });
                            if (check && check.typeId === 'minecraft:torch') hasTorch = true;
                        } catch (_) {}
                    }
                }
                if (!hasTorch && Math.random() > 0.7) {
                    dim.setBlockType(pos, 'minecraft:torch');
                }
            }
        } catch (_) {}
    } else if (action === 3) {
        // Add fence posts along paths
        const pos = { x: rx, y: by, z: rz };
        try {
            const below = dim.getBlock({ x: rx, y: by - 1, z: rz });
            const block = dim.getBlock(pos);
            if (block && block.typeId === 'minecraft:air' && below &&
                below.typeId === 'minecraft:grass_path') {
                // Check if at edge of path
                const side = dim.getBlock({ x: rx + 1, y: by - 1, z: rz });
                if (side && side.typeId !== 'minecraft:grass_path' && Math.random() > 0.6) {
                    dim.setBlockType(pos, 'minecraft:oak_fence');
                }
            }
        } catch (_) {}
    } else {
        // Plant flowers in empty grass spots
        const pos = { x: rx, y: by, z: rz };
        try {
            const block = dim.getBlock(pos);
            const below = dim.getBlock({ x: rx, y: by - 1, z: rz });
            if (block && block.typeId === 'minecraft:air' && below &&
                below.typeId === 'minecraft:grass_block' && Math.random() > 0.5) {
                const flowers = ['minecraft:poppy', 'minecraft:dandelion',
                    'minecraft:blue_orchid', 'minecraft:cornflower'];
                dim.setBlockType(pos, randomChoice(flowers));
            }
        } catch (_) {}
    }
}
