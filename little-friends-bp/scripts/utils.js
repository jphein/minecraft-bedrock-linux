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
