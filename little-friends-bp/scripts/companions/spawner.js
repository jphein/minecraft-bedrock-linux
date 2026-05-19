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
