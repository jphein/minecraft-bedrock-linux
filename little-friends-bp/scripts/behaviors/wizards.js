/**
 * Wandering magical wizards that appear, walk around, drop enchanted
 * books and magical items, then vanish in a puff of smoke.
 */
import { world, system, ItemStack } from '@minecraft/server';
import { randomChoice, randomNearby } from '../utils.js';

const WIZARD_NAMES = [
    'Merlin', 'Gandalf', 'Starweaver', 'Moonwhisper',
    'Sparklebeard', 'Dreamcaster', 'Glimmer', 'Fizzlepop',
];

const WIZARD_MESSAGES = [
    'A Wandering Wizard appears!',
    'A magical wizard has come to visit!',
    'The wizard smells the magic in this place!',
    'A wizard is never late... they arrive precisely when they mean to!',
];

const WIZARD_SAYINGS = [
    'Abracadabra! A gift for you!',
    'By the power of the moon... take this!',
    'Enchantments for the worthy!',
    'A little magic for a little friend!',
    'Hocus pocus! Catch!',
    'The stars told me you needed this!',
    'Alakazam! Here you go!',
    'Magic is best when shared!',
];

const WIZARD_GOODBYE = [
    'The wizard vanishes in a puff of sparkles!',
    'Farewell, young one! Until next time!',
    'The wizard tips their hat and disappears!',
    'Poof! The wizard is gone!',
];

// Enchanted books the wizard can drop
const ENCHANT_BOOKS = [
    'minecraft:enchanted_book',
];

// Other magical items
const MAGICAL_ITEMS = [
    ['minecraft:enchanted_book', 1],
    ['minecraft:enchanted_golden_apple', 1],
    ['minecraft:golden_apple', 2],
    ['minecraft:experience_bottle', 8],
    ['minecraft:ender_pearl', 4],
    ['minecraft:blaze_rod', 3],
    ['minecraft:glowstone_dust', 8],
    ['minecraft:nether_star', 1],
    ['minecraft:totem_of_undying', 1],
    ['minecraft:elytra', 1],
    ['minecraft:trident', 1],
    ['minecraft:diamond_sword', 1],
    ['minecraft:diamond_pickaxe', 1],
    ['minecraft:diamond_axe', 1],
    ['minecraft:diamond_helmet', 1],
    ['minecraft:diamond_chestplate', 1],
    ['minecraft:diamond_leggings', 1],
    ['minecraft:diamond_boots', 1],
    ['minecraft:netherite_ingot', 1],
    ['minecraft:spyglass', 1],
    ['minecraft:recovery_compass', 1],
    ['minecraft:echo_shard', 2],
    ['minecraft:amethyst_shard', 6],
    ['minecraft:heart_of_the_sea', 1],
    ['minecraft:conduit', 1],
    ['minecraft:beacon', 1],
    ['minecraft:dragon_egg', 1],
    ['minecraft:end_crystal', 1],
    ['minecraft:firework_rocket', 16],
    ['minecraft:name_tag', 3],
    ['minecraft:saddle', 1],
    ['minecraft:lead', 2],
    ['minecraft:music_disc_cat', 1],
    ['minecraft:music_disc_blocks', 1],
    ['minecraft:music_disc_pigstep', 1],
];

const lastVisit = new Map();
const VISIT_INTERVAL = 12000; // ~10 minutes

export function forceWizardVisit(player) {
    lastVisit.delete(player.name);
    checkWizardVisit(player, 999999999);
}

/**
 * Check if a wizard should visit.
 * @param {import('@minecraft/server').Player} player
 * @param {number} currentTick
 */
export function checkWizardVisit(player, currentTick) {
    const last = lastVisit.get(player.name) || 0;
    if (currentTick - last < VISIT_INTERVAL) return;

    lastVisit.set(player.name, currentTick);

    const dim = player.dimension;
    const loc = player.location;

    // Announcement
    player.onScreenDisplay.setTitle('A Wizard Appears!', {
        fadeInDuration: 10,
        stayDuration: 60,
        fadeOutDuration: 10,
        subtitle: randomChoice(WIZARD_MESSAGES),
    });

    // Spawn the wizard (evoker — looks like a wizard with robes!)
    let wizard = null;
    const spawnPos = randomNearby(loc, 10, 15);
    spawnPos.y = Math.floor(loc.y);
    try {
        wizard = dim.spawnEntity('minecraft:evocation_illager', spawnPos);
        wizard.addTag('little_wizard_visitor');
        wizard.nameTag = randomChoice(WIZARD_NAMES);
    } catch (_) {}

    // Wizard walks around dropping items
    let step = 0;
    const dropCount = 5 + Math.floor(Math.random() * 4); // 5-8 items
    let dropped = 0;

    const wizardInterval = system.runInterval(() => {
        if (step > 80 || !wizard) {
            system.clearRun(wizardInterval);
            // Wizard disappears
            try {
                if (wizard) {
                    const valid = typeof wizard.isValid === 'function' ? wizard.isValid() : wizard.isValid !== false;
                    if (valid) {
                        // Big sparkle poof
                        dim.spawnParticle('minecraft:large_explosion', wizard.location);
                        dim.spawnParticle('minecraft:villager_happy', {
                            x: wizard.location.x, y: wizard.location.y + 1, z: wizard.location.z
                        });
                        dim.spawnParticle('minecraft:villager_happy', {
                            x: wizard.location.x + 1, y: wizard.location.y + 2, z: wizard.location.z
                        });
                        wizard.kill();
                    }
                }
            } catch (_) {}
            player.onScreenDisplay.setActionBar(randomChoice(WIZARD_GOODBYE));
            return;
        }

        try {
            const valid = wizard && (typeof wizard.isValid === 'function' ? wizard.isValid() : wizard.isValid !== false);
            if (!valid) {
                system.clearRun(wizardInterval);
                return;
            }

            // Move wizard around slowly
            if (step % 8 === 0) {
                const wanderPos = randomNearby(loc, 3, 8);
                wanderPos.y = Math.floor(loc.y);
                wizard.teleport(wanderPos);
            }

            // Sparkle trail
            if (step % 3 === 0) {
                dim.spawnParticle('minecraft:villager_happy', {
                    x: wizard.location.x + (Math.random() - 0.5),
                    y: wizard.location.y + 1 + Math.random(),
                    z: wizard.location.z + (Math.random() - 0.5),
                });
            }

            // Drop an item every ~10 steps
            if (step % 10 === 5 && dropped < dropCount) {
                const [itemType, count] = randomChoice(MAGICAL_ITEMS);
                try {
                    const itemStack = new ItemStack(itemType, count);
                    dim.spawnItem(itemStack, {
                        x: wizard.location.x + (Math.random() - 0.5) * 2,
                        y: wizard.location.y + 1.5,
                        z: wizard.location.z + (Math.random() - 0.5) * 2,
                    });

                    // Magic particles around the drop
                    dim.spawnParticle('minecraft:villager_happy', {
                        x: wizard.location.x, y: wizard.location.y + 2, z: wizard.location.z
                    });

                    // Wizard says something
                    const players = dim.getPlayers({ location: wizard.location, maxDistance: 30 });
                    for (const p of players) {
                        p.onScreenDisplay.setActionBar(`[${wizard.nameTag}] ${randomChoice(WIZARD_SAYINGS)}`);
                    }
                } catch (_) {}
                dropped++;
            }
        } catch (_) {}

        step++;
    }, 4);
}
