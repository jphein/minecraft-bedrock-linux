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

/** Track auto-build state per player */
const autoBuildState = new Map();

// Build queue: Axie cycles through these, picking the next one each time
const BUILD_QUEUE = [
    'house', 'garden', 'farm', 'treehouse', 'bridge',
    'playground', 'tower', 'tunnel', 'rainbow',
];
const BUILD_INTERVAL = 2400; // ~2 minutes between builds

/**
 * Check if Axie should autonomously build something.
 * Axie continuously builds fun structures, cycling through the queue.
 * At sunset, she always prioritizes a house.
 * @param {import('@minecraft/server').Entity} axie
 * @param {import('@minecraft/server').Player} player
 */
export function checkAutonomousBuild(axie, player) {
    if (activeBuilds.has(player.name)) return;

    const currentTick = system.currentTick;
    const key = player.name;
    let state = autoBuildState.get(key);
    if (!state) {
        state = { lastBuild: 0, queueIndex: 0 };
        autoBuildState.set(key, state);
    }

    // Not enough time since last build
    if (currentTick - state.lastBuild < BUILD_INTERVAL) return;

    const timeOfDay = world.getTimeOfDay();
    const isSunset = timeOfDay >= 11000 && timeOfDay <= 11500;

    // Sunset always → house
    if (isSunset) {
        sayEvent(axie, 'axie_night_shelter');
        startBuild(axie, player, 'house');
        state.lastBuild = currentTick;
        return;
    }

    // Otherwise pick next from queue
    const templateName = BUILD_QUEUE[state.queueIndex % BUILD_QUEUE.length];
    sayEvent(axie, 'axie_building');
    startBuild(axie, player, templateName);
    state.lastBuild = currentTick;
    state.queueIndex++;
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
