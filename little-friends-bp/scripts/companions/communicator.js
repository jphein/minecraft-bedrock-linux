/**
 * Companion personality messages and action bar communication.
 */
import { world } from '@minecraft/server';
import { randomChoice } from '../utils.js';

const IDLE_MESSAGES = {
    'little:axie': [
        'La la la... building is fun!',
        'Ooh, what should we build next?',
        'I love exploring with you!',
        'Do you like my buildings?',
        'Axie is happy!',
        'Look at all these blocks!',
    ],
    'little:shelly': [
        "Don't worry, Shelly's here!",
        'Hmm... it\'s quiet. Too quiet.',
        'Yay! Daytime is the best!',
        "I'll stay close tonight.",
        'Shelly is on guard!',
        'You are safe with me!',
    ],
    'little:bamboo': [
        '...yawn...',
        'Bamboo is sleepy...',
        'Mmm, I smell something nice!',
        "I'll go look around soon!",
        'Bamboo loves flowers!',
        '...munch munch...',
    ],
};

const EVENT_MESSAGES = {
    axie_building: [
        'Ooh! I\'ll build that right away!',
        'Building time! Yay!',
        'Leave it to Axie!',
    ],
    axie_done: [
        'Ta-da! Do you like it?',
        'All done! Pretty, right?',
        'Axie built it just for you!',
    ],
    axie_night_shelter: [
        'It\'s getting dark! Let me build a house!',
        'Time for a cozy shelter!',
    ],
    shelly_warning: [
        'Shelly hears something scary...',
        'Something is coming...',
        'Stay close to Shelly!',
    ],
    shelly_fighting: [
        'Stay behind me!',
        "I'll protect you!",
        'Shelly to the rescue!',
    ],
    shelly_safe: [
        'All safe now!',
        'The scary thing is gone!',
        'Shelly kept you safe!',
    ],
    bamboo_gift: [
        'Here you go! A present!',
        'Bamboo found something!',
        '...yawn... oh! Look what I found!',
    ],
    bamboo_foraging: [
        "I'll go look around... be right back!",
        'Bamboo smells something good nearby!',
    ],
    bamboo_pickup: [
        'Ooh, you dropped this!',
        'Bamboo picked that up for you!',
    ],
    companion_scared: [
        'Eek!',
        'That was loud!',
        '...Bamboo doesn\'t like that!',
    ],
    companion_teleport: [
        'Wait for me!',
        "I'm coming!",
        'Whoosh!',
    ],
};

const INTRO_MESSAGES = {
    'little:axie': 'Hi new friend! I\'m Axie! Let\'s build stuff!',
    'little:shelly': "Hello! I'm Shelly. I'll keep you safe!",
    'little:bamboo': '...yawn... oh hi! I\'m Bamboo. Want a flower?',
};

/**
 * Show a companion message to the nearest player via action bar.
 * @param {import('@minecraft/server').Entity} companion
 * @param {string} message
 */
export function say(companion, message) {
    try {
        const valid = typeof companion.isValid === 'function' ? companion.isValid() : companion.isValid;
        if (!valid) return;
        const name = companion.typeId === 'little:axie' ? 'Axie'
            : companion.typeId === 'little:shelly' ? 'Shelly'
            : 'Bamboo';
        const players = companion.dimension.getPlayers({
            location: companion.location,
            maxDistance: 40,
        });
        for (const player of players) {
            player.onScreenDisplay.setActionBar(`[${name}] ${message}`);
        }
    } catch (_) {}
}

/**
 * Show a random idle message for a companion.
 * @param {import('@minecraft/server').Entity} companion
 */
export function sayIdle(companion) {
    const messages = IDLE_MESSAGES[companion.typeId];
    if (messages) {
        say(companion, randomChoice(messages));
    }
}

/**
 * Show an event-triggered message.
 * @param {import('@minecraft/server').Entity} companion
 * @param {string} eventKey
 */
export function sayEvent(companion, eventKey) {
    const messages = EVENT_MESSAGES[eventKey];
    if (messages) {
        say(companion, randomChoice(messages));
    }
}

/**
 * Show companion intro message.
 * @param {import('@minecraft/server').Entity} companion
 */
export function sayIntro(companion) {
    const message = INTRO_MESSAGES[companion.typeId];
    if (message) {
        say(companion, message);
    }
}
