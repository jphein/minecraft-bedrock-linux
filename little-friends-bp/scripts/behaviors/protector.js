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
