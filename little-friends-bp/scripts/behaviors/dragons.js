/**
 * Friendly dragons that visit periodically, compliment the builds,
 * and leave giant trees and treasure chests as presents.
 */
import { world, system, ItemStack } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

const DRAGON_MESSAGES = [
    'What a beautiful garden! Here, have a present!',
    'Wow! You built all this? Amazing!',
    'The prettiest place I\'ve seen from the sky!',
    'Your flowers are lovely! I brought you something!',
    'A dragon likes what a dragon sees! Gift time!',
    'So colorful! This deserves a treasure!',
    'I flew all the way here because it looked so pretty!',
    'Your friends are so helpful! Have a gift!',
    'The best builders in all the land!',
    'Even dragons love flowers! Here you go!',
];

const TREASURE_ITEMS = [
    ['minecraft:diamond', 3],
    ['minecraft:emerald', 5],
    ['minecraft:gold_ingot', 8],
    ['minecraft:cookie', 16],
    ['minecraft:cake', 1],
    ['minecraft:golden_apple', 2],
    ['minecraft:name_tag', 1],
    ['minecraft:spyglass', 1],
    ['minecraft:amethyst_shard', 6],
    ['minecraft:glow_berries', 10],
];

/** Track last dragon visit per player */
const lastVisit = new Map();
const VISIT_INTERVAL = 24000; // ~20 minutes

/**
 * Place a giant tree (oak trunk + big leaf canopy).
 * @param {import('@minecraft/server').Dimension} dim
 * @param {import('@minecraft/server').Vector3} base
 */
function placeGiantTree(dim, base) {
    const LOG = 'minecraft:oak_log';
    const LEAF = 'minecraft:oak_leaves';

    // Tall trunk (8-12 blocks)
    const height = 8 + Math.floor(Math.random() * 5);
    for (let y = 0; y < height; y++) {
        try { dim.setBlockType({ x: base.x, y: base.y + y, z: base.z }, LOG); } catch (_) {}
    }

    // Big leaf canopy at top
    const topY = base.y + height;
    for (let dy = -1; dy <= 3; dy++) {
        const radius = dy <= 0 ? 4 : dy === 1 ? 3 : dy === 2 ? 2 : 1;
        for (let dx = -radius; dx <= radius; dx++) {
            for (let dz = -radius; dz <= radius; dz++) {
                if (dx * dx + dz * dz > radius * radius + 1) continue;
                const pos = { x: base.x + dx, y: topY + dy, z: base.z + dz };
                try {
                    const block = dim.getBlock(pos);
                    if (block && block.typeId === 'minecraft:air') {
                        dim.setBlockType(pos, LEAF);
                    }
                } catch (_) {}
            }
        }
    }
}

/**
 * Place a treasure chest with random goodies.
 * @param {import('@minecraft/server').Dimension} dim
 * @param {import('@minecraft/server').Vector3} pos
 */
function placeTreasure(dim, pos) {
    try {
        // Place chest
        dim.setBlockType(pos, 'minecraft:chest');

        // Surround with gold blocks as a little treasure pile
        const accents = [
            { x: pos.x - 1, y: pos.y, z: pos.z },
            { x: pos.x + 1, y: pos.y, z: pos.z },
            { x: pos.x, y: pos.y, z: pos.z - 1 },
            { x: pos.x, y: pos.y, z: pos.z + 1 },
        ];
        for (const a of accents) {
            try {
                const block = dim.getBlock(a);
                if (block && block.typeId === 'minecraft:air') {
                    dim.setBlockType(a, Math.random() > 0.5 ? 'minecraft:gold_block' : 'minecraft:glowstone');
                }
            } catch (_) {}
        }

        // Spawn treasure items on top of the chest
        const [itemType, count] = randomChoice(TREASURE_ITEMS);
        const itemStack = new ItemStack(itemType, count);
        dim.spawnItem(itemStack, { x: pos.x + 0.5, y: pos.y + 1.5, z: pos.z + 0.5 });

        // Second treasure
        const [itemType2, count2] = randomChoice(TREASURE_ITEMS);
        const itemStack2 = new ItemStack(itemType2, count2);
        dim.spawnItem(itemStack2, { x: pos.x + 0.5, y: pos.y + 2, z: pos.z + 0.5 });
    } catch (_) {}
}

/**
 * Check if a dragon should visit. Called from main tick loop.
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function forceDragonVisit(player) {
    lastVisit.delete(player.name);
    checkDragonVisit(player, 999999999);
}

export function checkDragonVisit(player, currentTick) {
    const last = lastVisit.get(player.name) || 0;
    if (currentTick - last < VISIT_INTERVAL) return;

    lastVisit.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;

    // Dragon announcement with particles
    player.onScreenDisplay.setTitle('A Dragon Visits!', {
        fadeInDuration: 10,
        stayDuration: 60,
        fadeOutDuration: 10,
        subtitle: randomChoice(DRAGON_MESSAGES),
    });

    // Spawn a flock of dragons (phantoms — they actually fly!) across the sky
    // Plus one real ender dragon as the "Big Dragon" leading the flock
    const startX = loc.x - 60;
    const endX = loc.x + 60;
    const skyY = loc.y + 20;

    const flock = [
        { name: 'Big Dragon',    type: 'minecraft:ender_dragon', yOff: 10, zOff: 0,   speed: 2.5, wave: 0.1 },
        { name: 'Mama Dragon',   type: 'minecraft:phantom',      yOff: 0,  zOff: 0,   speed: 3,   wave: 0.15 },
        { name: 'Papa Dragon',   type: 'minecraft:phantom',      yOff: 5,  zOff: -8,  speed: 3.2, wave: 0.12 },
        { name: 'Baby Dragon',   type: 'minecraft:phantom',      yOff: -3, zOff: 5,   speed: 2.8, wave: 0.25 },
        { name: 'Tiny Dragon',   type: 'minecraft:phantom',      yOff: -1, zOff: -4,  speed: 2.6, wave: 0.3 },
        { name: 'Little Dragon', type: 'minecraft:phantom',      yOff: 2,  zOff: 7,   speed: 3.1, wave: 0.2 },
        { name: 'Swift Dragon',  type: 'minecraft:phantom',      yOff: 7,  zOff: -6,  speed: 3.4, wave: 0.18 },
    ];

    const dragons = [];
    for (const f of flock) {
        try {
            const d = dim.spawnEntity(f.type, {
                x: startX - Math.random() * 15,
                y: skyY + f.yOff,
                z: loc.z + f.zOff,
            });
            d.addTag('little_dragon_visitor');
            d.nameTag = f.name;
            dragons.push({ entity: d, ...f });
        } catch (_) {}
    }

    // Fly the flock across the sky
    let step = 0;
    const flyInterval = system.runInterval(() => {
        let allDone = true;
        for (const d of dragons) {
            const x = startX + step * d.speed;
            if (x > endX) {
                try { if (d.entity) d.entity.kill(); } catch (_) {}
                d.entity = null;
                continue;
            }
            allDone = false;
            try {
                const valid = d.entity && (typeof d.entity.isValid === 'function' ? d.entity.isValid() : d.entity.isValid !== false);
                if (valid) {
                    d.entity.teleport({
                        x,
                        y: skyY + d.yOff + Math.sin(step * d.wave) * 3,
                        z: loc.z + d.zOff + Math.cos(step * d.wave * 0.7) * 2,
                    });
                    // Dragon breath trail behind each one
                    if (step % 2 === 0) {
                        dim.spawnParticle('minecraft:dragon_breath_trail', {
                            x: x - 3, y: skyY + d.yOff, z: loc.z + d.zOff,
                        });
                    }
                }
            } catch (_) {}
        }
        if (allDone) system.clearRun(flyInterval);
        step++;
    }, 3);

    // After the flyover, leave presents
    system.runTimeout(() => {
        // Place 1-2 giant trees nearby
        const treePos1 = randomNearby(loc, 10, 20);
        treePos1.y = Math.floor(loc.y);
        placeGiantTree(dim, treePos1);

        if (Math.random() > 0.4) {
            const treePos2 = randomNearby(loc, 15, 25);
            treePos2.y = Math.floor(loc.y);
            placeGiantTree(dim, treePos2);
        }

        // Place 2-3 treasure chests
        for (let i = 0; i < 2 + Math.floor(Math.random() * 2); i++) {
            const chestPos = randomNearby(loc, 5, 15);
            chestPos.y = Math.floor(loc.y);
            // Find ground level
            try {
                for (let dy = 5; dy >= -5; dy--) {
                    const checkPos = { x: chestPos.x, y: chestPos.y + dy, z: chestPos.z };
                    const block = dim.getBlock(checkPos);
                    const above = dim.getBlock({ x: checkPos.x, y: checkPos.y + 1, z: checkPos.z });
                    if (block && above && block.typeId !== 'minecraft:air' && above.typeId === 'minecraft:air') {
                        placeTreasure(dim, { x: checkPos.x, y: checkPos.y + 1, z: checkPos.z });
                        break;
                    }
                }
            } catch (_) {}
        }

        // Sparkle explosion where presents land
        try {
            dim.spawnParticle('minecraft:villager_happy', { x: loc.x, y: loc.y + 2, z: loc.z });
            dim.spawnParticle('minecraft:villager_happy', { x: loc.x + 3, y: loc.y + 1, z: loc.z + 3 });
            dim.spawnParticle('minecraft:villager_happy', { x: loc.x - 3, y: loc.y + 1, z: loc.z - 3 });
        } catch (_) {}

        player.onScreenDisplay.setActionBar('[Dragon] Enjoy the presents! See you next time!');
    }, 80); // 4 seconds after flyover starts
}
