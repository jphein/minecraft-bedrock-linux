/**
 * Companion following logic + anti-blocking.
 * Companions stay near but never block the player's path.
 */
import { distanceXZ } from '../utils.js';
import { sayEvent, say } from './communicator.js';

const TELEPORT_DISTANCE = 30;
const NUDGE_DISTANCE = 10;
const TOO_CLOSE = 1.5; // If closer than this, move out of the way

const MOVE_MESSAGES = [
    'Oops, sorry!',
    'Coming through!',
    'Let me get out of the way!',
    'Excuse me!',
    'Whoops!',
];

/**
 * Keep a companion near their owner but NEVER in the way.
 * @param {import('@minecraft/server').Entity} companion
 * @param {import('@minecraft/server').Player} owner
 */
export function updateFollowing(companion, owner) {
    try {
        const dist = distanceXZ(companion.location, owner.location);

        if (dist > TELEPORT_DISTANCE) {
            // Far away — full teleport near the player
            const angle = Math.random() * 2 * Math.PI;
            const offsetDist = 3 + Math.random() * 2;
            const dest = {
                x: owner.location.x + Math.cos(angle) * offsetDist,
                y: owner.location.y,
                z: owner.location.z + Math.sin(angle) * offsetDist,
            };
            try {
                companion.teleport(dest);
                owner.dimension.spawnParticle('minecraft:large_explosion', dest);
                sayEvent(companion, 'companion_teleport');
            } catch (_) {}

        } else if (dist < TOO_CLOSE) {
            // TOO CLOSE — blocking the player! Jump out of the way
            // Move to the side/behind the player based on their facing
            const viewDir = owner.getViewDirection();
            // Move perpendicular to player's view (to the side)
            const sideX = -viewDir.z;
            const sideZ = viewDir.x;
            // Pick left or right randomly, 3-4 blocks away
            const sign = Math.random() > 0.5 ? 1 : -1;
            const dest = {
                x: owner.location.x + sideX * sign * 3.5,
                y: owner.location.y,
                z: owner.location.z + sideZ * sign * 3.5,
            };
            try {
                companion.teleport(dest);
                say(companion, MOVE_MESSAGES[Math.floor(Math.random() * MOVE_MESSAGES.length)]);
            } catch (_) {}

        } else if (dist > NUDGE_DISTANCE) {
            // Medium distance — nudge toward player
            const dx = owner.location.x - companion.location.x;
            const dz = owner.location.z - companion.location.z;
            const len = Math.sqrt(dx * dx + dz * dz) || 1;
            const dest = {
                x: companion.location.x + (dx / len) * (dist * 0.6),
                y: owner.location.y,
                z: companion.location.z + (dz / len) * (dist * 0.6),
            };
            try {
                companion.teleport(dest);
            } catch (_) {}
        }
        // 1.5 - 10 blocks: comfortable range, let entity wander naturally
    } catch (_) {}
}
