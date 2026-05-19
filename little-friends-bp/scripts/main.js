/**
 * Little Friends — Main entry point.
 * Registers event handlers and runs the companion tick loop.
 */
import { world, system, ItemStack } from '@minecraft/server';
import { beginSpawnSequence, getCompanion, getCompanions, checkAndRespawn } from './companions/spawner.js';
import { updateFollowing } from './companions/follower.js';
import { say, sayIdle, sayEvent } from './companions/communicator.js';
import { handleChatCommand, startBuild, tickBuilder, checkAutonomousBuild } from './behaviors/builder.js';
import { TEMPLATES } from './templates/buildings.js';
import { checkThreats, checkSafe, nightlightEffect } from './behaviors/protector.js';
import { decorate } from './behaviors/gatherer.js';
import { checkDragonVisit, forceDragonVisit } from './behaviors/dragons.js';
import { checkUnicornVisit, forceUnicornVisit } from './behaviors/unicorns.js';
import { checkDonkeyVisit, forceDonkeyVisit } from './behaviors/donkeys.js';
import { checkWizardVisit, forceWizardVisit } from './behaviors/wizards.js';

/** Summon a visitor on demand (bypasses cooldown) */
function summonVisitor(type, player) {
    if (type === 'dragon') forceDragonVisit(player);
    else if (type === 'unicorn') forceUnicornVisit(player);
    else if (type === 'donkey') forceDonkeyVisit(player);
    else if (type === 'wizard') forceWizardVisit(player);
}
import { tickMagic } from './behaviors/magic.js';
import { tickWonder } from './behaviors/wonder.js';
import { randomChoice, distanceXZ } from './utils.js';

/** Track which players have had companions spawned */
const initializedPlayers = new Set();

// --- Player spawn: trigger companion spawn sequence + starter gear ---
world.afterEvents.playerSpawn.subscribe((event) => {
    if (!event.initialSpawn) return;
    const player = event.player;

    if (initializedPlayers.has(player.name)) return;
    initializedPlayers.add(player.name);

    // Give elytra and fireworks
    system.run(() => {
        try {
            const inv = player.getComponent('minecraft:inventory')?.container;
            if (inv) {
                // Equip elytra in chestplate slot
                const equip = player.getComponent('minecraft:equippable');
                if (equip) {
                    equip.setEquipment('Chest', new ItemStack('minecraft:elytra', 1));
                }
                // Give 64 firework rockets
                inv.addItem(new ItemStack('minecraft:firework_rocket', 64));
            }
        } catch (_) {}
    });

    // Check if companions already exist (world reload)
    const existing = getCompanions(player);
    if (existing.length >= 3) return;

    beginSpawnSequence(player);
});

// --- Chat commands ---
// Handle chat for building AND companion interaction commands.
// Try every known chat event API in order.

/**
 * Process a chat message from a player.
 * Handles building commands AND companion commands (move, stop, come, etc.)
 */
function processChat(player, message) {
    const word = message.trim().toLowerCase();

    // Building commands
    const axie = getCompanion(player, 'little:axie');
    if (axie && TEMPLATES[word]) {
        system.run(() => startBuild(axie, player, word));
        return;
    }

    // Companion interaction commands
    const companions = getCompanions(player);
    if (word === 'move' || word === 'go' || word === 'shoo') {
        // Tell all companions to move away
        for (const c of companions) {
            try {
                const angle = Math.random() * 2 * Math.PI;
                c.teleport({
                    x: player.location.x + Math.cos(angle) * 6,
                    y: player.location.y,
                    z: player.location.z + Math.sin(angle) * 6,
                });
                say(c, 'Oops, sorry! Moving!');
            } catch (_) {}
        }
    } else if (word === 'come' || word === 'here') {
        for (const c of companions) {
            try {
                const angle = Math.random() * 2 * Math.PI;
                c.teleport({
                    x: player.location.x + Math.cos(angle) * 3,
                    y: player.location.y,
                    z: player.location.z + Math.sin(angle) * 3,
                });
                say(c, "I'm here!");
            } catch (_) {}
        }
    } else if (word === 'stop') {
        for (const c of companions) {
            try { say(c, 'Okay, stopping!'); } catch (_) {}
        }
    } else if (word === 'hi' || word === 'hello' || word === 'hey') {
        for (const c of companions) {
            try { say(c, 'Hi! I love you!'); } catch (_) {}
        }
    } else if (word === 'help') {
        player.onScreenDisplay.setActionBar('Say: move, come, hi, house, treehouse, rainbow, garden, dragon, unicorn, wizard, donkeys...');
    } else if (word === 'dragon' || word === 'dragons') {
        summonVisitor('dragon', player);
    } else if (word === 'unicorn' || word === 'unicorns') {
        summonVisitor('unicorn', player);
    } else if (word === 'wizard' || word === 'wizards') {
        summonVisitor('wizard', player);
    } else if (word === 'donkey' || word === 'donkeys' || word === 'tidy') {
        summonVisitor('donkey', player);
    }
}

let chatSetup = false;

// Method 1: beforeEvents.chatSend (experimental)
try {
    world.beforeEvents.chatSend.subscribe((event) => {
        const word = event.message.trim().toLowerCase();
        if (TEMPLATES[word] || ['move','go','shoo','come','here','stop','hi','hello','hey','help'].includes(word)) {
            event.cancel = true;
        }
        system.run(() => processChat(event.sender, event.message));
    });
    chatSetup = true;
} catch (_) {}

// Method 2: afterEvents.chatSend (experimental)
if (!chatSetup) {
    try {
        world.afterEvents.chatSend.subscribe((event) => {
            processChat(event.sender, event.message);
        });
        chatSetup = true;
    } catch (_) {}
}

// Always subscribe to scriptEvent (/scriptevent little:house, /scriptevent little:move)
try {
    system.afterEvents.scriptEventReceive.subscribe((event) => {
        if (event.id.indexOf('little:') !== 0) return;
        const command = event.id.replace('little:', '');
        const players = world.getPlayers();
        for (const player of players) {
            processChat(player, command);
        }
    });
} catch (_) {}

// --- Main tick loop (runs every 20 ticks = 1 second) ---
let tickCount = 0;

system.runInterval(() => {
    tickCount++;
    const currentTick = system.currentTick;

    for (const player of world.getPlayers()) {
        // Respawn check every 10 seconds
        if (tickCount % 10 === 0) {
            checkAndRespawn(player);
        }

        const axie = getCompanion(player, 'little:axie');
        const shelly = getCompanion(player, 'little:shelly');
        const bamboo = getCompanion(player, 'little:bamboo');

        // Validate entities are still alive
        const isOk = (e) => { try { return e && (typeof e.isValid === 'function' ? e.isValid() : e.isValid !== false) && e.typeId; } catch(_) { return false; } };
        const a = isOk(axie) ? axie : null;
        const s = isOk(shelly) ? shelly : null;
        const b = isOk(bamboo) ? bamboo : null;

        // --- Follower teleport checks ---
        if (a) updateFollowing(a, player);
        if (s) updateFollowing(s, player);
        if (b) updateFollowing(b, player);

        // --- Axie: autonomous building ---
        if (a) checkAutonomousBuild(a, player);

        // --- Shelly: threat warnings + nightlight ---
        if (s) {
            checkThreats(s, player, currentTick);
            checkSafe(s, player, currentTick);
            nightlightEffect(s);
        }

        // --- Bamboo: decorating ---
        if (b) {
            decorate(b, player, currentTick);
        }

        // --- Dragon and unicorn visits ---
        checkDragonVisit(player, currentTick);
        checkUnicornVisit(player, currentTick);
        checkDonkeyVisit(player, currentTick);
        checkWizardVisit(player, currentTick);

        // --- Magical world events ---
        tickMagic(player, currentTick);
        tickWonder(player, currentTick);

        // --- Idle chatter (every 20-40 seconds, pick a random companion) ---
        if (tickCount % 25 === 0) {
            const companions = [a, s, b].filter(Boolean);
            if (companions.length > 0) {
                sayIdle(randomChoice(companions));
            }
        }
    }
}, 20);

// --- Builder tick (runs every 2 ticks for smooth block placement) ---
system.runInterval(() => {
    tickBuilder();
}, 2);

// --- Axie flower placement (every ~3 minutes, place a random flower) ---
system.runInterval(() => {
    for (const player of world.getPlayers()) {
        const axie = getCompanion(player, 'little:axie');
        if (!axie) continue;
        const flowers = [
            'minecraft:poppy', 'minecraft:dandelion', 'minecraft:blue_orchid',
            'minecraft:oxeye_daisy', 'minecraft:cornflower',
        ];
        const pos = {
            x: Math.floor(axie.location.x + (Math.random() - 0.5) * 4),
            y: Math.floor(axie.location.y),
            z: Math.floor(axie.location.z + (Math.random() - 0.5) * 4),
        };
        try {
            // Only place on grass/dirt
            const block = player.dimension.getBlock(pos);
            const below = player.dimension.getBlock({ x: pos.x, y: pos.y - 1, z: pos.z });
            if (block && below) {
                const belowType = below.typeId;
                if ((belowType === 'minecraft:grass_block' || belowType === 'minecraft:dirt')
                    && block.typeId === 'minecraft:air') {
                    player.dimension.setBlockType(pos, randomChoice(flowers));
                    player.dimension.spawnParticle('minecraft:villager_happy',
                        { x: pos.x + 0.5, y: pos.y + 0.5, z: pos.z + 0.5 });
                }
            }
        } catch (_) {}
    }
}, 3600); // ~3 minutes

// --- Fear reactions: scatter from explosions ---
world.afterEvents.explosion.subscribe((event) => {
    for (const player of world.getPlayers()) {
        const companions = getCompanions(player);
        for (const companion of companions) {
            const d = distanceXZ(companion.location, event.source?.location ?? { x: 0, y: 0, z: 0 });
            if (d < 10) {
                // Scatter away from explosion
                const dx = companion.location.x - (event.source?.location?.x ?? companion.location.x);
                const dz = companion.location.z - (event.source?.location?.z ?? companion.location.z);
                const len = Math.sqrt(dx * dx + dz * dz) || 1;
                try {
                    companion.teleport({
                        x: companion.location.x + (dx / len) * 5,
                        y: companion.location.y,
                        z: companion.location.z + (dz / len) * 5,
                    });
                    sayEvent(companion, 'companion_scared');
                } catch (_) {}
            }
        }
    }
});
