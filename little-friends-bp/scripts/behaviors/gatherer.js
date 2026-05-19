/**
 * Bamboo's decorator behavior — places flowers, lanterns, and decorative blocks
 * around the player to make everything pretty.
 */
import { world } from '@minecraft/server';
import { randomChoice } from '../utils.js';
import { say } from '../companions/communicator.js';

const DECORATIONS = [
    'minecraft:poppy',
    'minecraft:dandelion',
    'minecraft:blue_orchid',
    'minecraft:oxeye_daisy',
    'minecraft:cornflower',
    'minecraft:allium',
    'minecraft:azure_bluet',
    'minecraft:red_tulip',
    'minecraft:pink_tulip',
    'minecraft:orange_tulip',
    'minecraft:white_tulip',
    'minecraft:lily_of_the_valley',
    'minecraft:lantern',
    'minecraft:soul_lantern',
];

const FLOWERS_ONLY = DECORATIONS.filter(d => d !== 'minecraft:lantern' && d !== 'minecraft:soul_lantern');
const LANTERNS = ['minecraft:lantern', 'minecraft:soul_lantern'];

const INTERIOR_DECOR = [
    'minecraft:candle',
    'minecraft:white_candle',
    'minecraft:pink_candle',
    'minecraft:light_blue_candle',
    'minecraft:flower_pot',
    'minecraft:red_carpet',
    'minecraft:orange_carpet',
    'minecraft:yellow_carpet',
    'minecraft:lime_carpet',
    'minecraft:light_blue_carpet',
    'minecraft:pink_carpet',
    'minecraft:purple_carpet',
    'minecraft:white_carpet',
];

// Blocks that count as "indoor floor" (built by Axie)
const INDOOR_FLOORS = [
    'minecraft:oak_planks', 'minecraft:spruce_planks', 'minecraft:birch_planks',
    'minecraft:cobblestone', 'minecraft:stone_bricks', 'minecraft:stone',
    'minecraft:oak_slab', 'minecraft:quartz_block', 'minecraft:pink_wool',
    'minecraft:purple_wool', 'minecraft:white_wool',
];

const DECORATE_MESSAGES = [
    'Ooh, this spot needs a flower!',
    'Pretty pretty pretty!',
    'Bamboo is decorating!',
    'This will look so nice!',
    'A little color here...',
    'Making it beautiful!',
];

const INTERIOR_MESSAGES = [
    'This room needs some color!',
    'Ooh, a cozy carpet here!',
    'Bamboo is making it homey!',
    'A candle for ambiance!',
    'Interior decorating time!',
];

const LANTERN_MESSAGES = [
    'It\'s dark here... let me fix that!',
    'A little light for you!',
    'Bamboo doesn\'t like the dark!',
];

/** Track last decoration time per player */
const lastDecorateTime = new Map();
const DECORATE_INTERVAL = 200; // every ~10 seconds

/**
 * Bamboo places decorations near the player.
 * During day: flowers on grass/dirt.
 * At night: lanterns on solid blocks.
 * @param {import('@minecraft/server').Entity} bamboo
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function decorate(bamboo, player, currentTick) {
    const last = lastDecorateTime.get(player.name) || 0;
    if (currentTick - last < DECORATE_INTERVAL) return;

    const timeOfDay = world.getTimeOfDay();
    const isNight = timeOfDay >= 13000 || timeOfDay <= 500;

    // Pick a random spot near the PLAYER (1-4 blocks away)
    // This way Bamboo decorates wherever the player is standing — inside houses too
    const angle = Math.random() * 2 * Math.PI;
    const dist = 1 + Math.random() * 3;
    const pos = {
        x: Math.floor(player.location.x + Math.cos(angle) * dist),
        y: Math.floor(player.location.y),
        z: Math.floor(player.location.z + Math.sin(angle) * dist),
    };

    try {
        const block = player.dimension.getBlock(pos);
        const below = player.dimension.getBlock({ x: pos.x, y: pos.y - 1, z: pos.z });
        if (!block || !below) return;

        const belowType = below.typeId;
        const blockType = block.typeId;

        if (blockType !== 'minecraft:air') return;
        if (belowType === 'minecraft:air' || belowType === 'minecraft:water') return;

        const isIndoor = INDOOR_FLOORS.includes(belowType);

        if (isIndoor) {
            // Interior decorating: carpets, candles, flower pots
            player.dimension.setBlockType(pos, randomChoice(INTERIOR_DECOR));
            player.dimension.spawnParticle('minecraft:villager_happy',
                { x: pos.x + 0.5, y: pos.y + 0.5, z: pos.z + 0.5 });
            say(bamboo, randomChoice(INTERIOR_MESSAGES));
            lastDecorateTime.set(player.name, currentTick);
        } else if (isNight) {
            // Nighttime outdoor: lanterns
            player.dimension.setBlockType(pos, randomChoice(LANTERNS));
            player.dimension.spawnParticle('minecraft:villager_happy',
                { x: pos.x + 0.5, y: pos.y + 0.5, z: pos.z + 0.5 });
            say(bamboo, randomChoice(LANTERN_MESSAGES));
            lastDecorateTime.set(player.name, currentTick);
        } else if (belowType === 'minecraft:grass_block' || belowType === 'minecraft:dirt') {
            // Daytime outdoor: flowers
            player.dimension.setBlockType(pos, randomChoice(FLOWERS_ONLY));
            player.dimension.spawnParticle('minecraft:villager_happy',
                { x: pos.x + 0.5, y: pos.y + 0.5, z: pos.z + 0.5 });
            say(bamboo, randomChoice(DECORATE_MESSAGES));
            lastDecorateTime.set(player.name, currentTick);
        }
    } catch (_) {}
}
