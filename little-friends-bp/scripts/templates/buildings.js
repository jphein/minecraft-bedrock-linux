/**
 * Building templates for Axie.
 * Each template is an array of { x, y, z, block } relative offsets.
 * Origin (0,0,0) is the player's feet position.
 * z = forward (player facing direction), x = right, y = up.
 */

// 5x5 house with door, windows, torches, and roof
export const HOUSE = (() => {
    const blocks = [];
    const W = 'minecraft:oak_planks';
    const G = 'minecraft:glass';
    const D = 'minecraft:oak_door'; // bottom half
    const T = 'minecraft:torch';
    const S = 'minecraft:oak_slab'; // roof

    // Floor: 5x5 at y=0, starting 2 blocks forward
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 0, z, block: W });
        }
    }

    // Walls: 3 blocks high at y=1,2,3
    for (let y = 1; y <= 3; y++) {
        for (let x = -2; x <= 2; x++) {
            for (let z = 2; z <= 6; z++) {
                const isEdge = x === -2 || x === 2 || z === 2 || z === 6;
                if (!isEdge) continue;

                // Door opening at front center (z=2, x=0) at y=1,2
                if (z === 2 && x === 0 && y <= 2) continue;

                // Windows: glass at y=2 on sides
                if (y === 2 && ((x === -2 && z === 4) || (x === 2 && z === 4) || (z === 6 && x === 0))) {
                    blocks.push({ x, y, z, block: G });
                    continue;
                }

                blocks.push({ x, y, z, block: W });
            }
        }
    }

    // Roof: slabs at y=4
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 4, z, block: S });
        }
    }

    // Door at front center
    blocks.push({ x: 0, y: 1, z: 2, block: 'minecraft:oak_door' });

    // Torches inside at y=3 on walls
    blocks.push({ x: -1, y: 3, z: 5, block: T });
    blocks.push({ x: 1, y: 3, z: 5, block: T });

    return blocks;
})();

// 3-high cobblestone wall in a circle (8-block radius)
export const WALL = (() => {
    const blocks = [];
    const W = 'minecraft:cobblestone';
    const radius = 8;

    for (let y = 1; y <= 3; y++) {
        for (let angle = 0; angle < 360; angle += 5) {
            const rad = (angle * Math.PI) / 180;
            const x = Math.round(Math.cos(rad) * radius);
            const z = Math.round(Math.sin(rad) * radius);
            blocks.push({ x, y, z, block: W });
        }
    }
    return blocks;
})();

// 10-block bridge forward
export const BRIDGE = (() => {
    const blocks = [];
    const W = 'minecraft:oak_planks';
    const F = 'minecraft:oak_fence';

    for (let z = 1; z <= 10; z++) {
        // 3-wide bridge deck at y=0
        blocks.push({ x: -1, y: 0, z, block: W });
        blocks.push({ x: 0, y: 0, z, block: W });
        blocks.push({ x: 1, y: 0, z, block: W });
        // Fences on sides
        blocks.push({ x: -2, y: 1, z, block: F });
        blocks.push({ x: 2, y: 1, z, block: F });
    }
    return blocks;
})();

// 5x5 farm with water channel
export const FARM = (() => {
    const blocks = [];
    const D = 'minecraft:farmland';
    const W = 'minecraft:water';

    // Water channel down the middle (z direction)
    for (let z = 2; z <= 6; z++) {
        blocks.push({ x: 0, y: 0, z, block: W });
    }

    // Farmland on both sides
    for (let z = 2; z <= 6; z++) {
        blocks.push({ x: -2, y: 0, z, block: D });
        blocks.push({ x: -1, y: 0, z, block: D });
        blocks.push({ x: 1, y: 0, z, block: D });
        blocks.push({ x: 2, y: 0, z, block: D });
    }
    return blocks;
})();

// 3x3 lookout tower, 8 blocks tall
export const TOWER = (() => {
    const blocks = [];
    const W = 'minecraft:cobblestone';
    const L = 'minecraft:ladder';
    const T = 'minecraft:torch';
    const S = 'minecraft:oak_slab';

    // Walls 8 high
    for (let y = 0; y <= 7; y++) {
        for (let x = -1; x <= 1; x++) {
            for (let z = 2; z <= 4; z++) {
                const isEdge = x === -1 || x === 1 || z === 2 || z === 4;
                if (!isEdge) continue;
                // Leave door at z=2, x=0, y=0,1
                if (z === 2 && x === 0 && y <= 1) continue;
                blocks.push({ x, y, z, block: W });
            }
        }
        // Ladder inside
        if (y <= 6) {
            blocks.push({ x: 0, y, z: 3, block: L });
        }
    }

    // Top platform
    for (let x = -1; x <= 1; x++) {
        for (let z = 2; z <= 4; z++) {
            blocks.push({ x, y: 8, z, block: S });
        }
    }

    // Torch on top
    blocks.push({ x: 0, y: 9, z: 3, block: T });

    return blocks;
})();

// Treehouse: oak log trunk + platform + walls + ladder
export const TREEHOUSE = (() => {
    const blocks = [];
    const LOG = 'minecraft:oak_log';
    const W = 'minecraft:oak_planks';
    const L = 'minecraft:ladder';
    const F = 'minecraft:oak_fence';
    const T = 'minecraft:torch';
    const LEAF = 'minecraft:oak_leaves';

    // Trunk: 6 high at center
    for (let y = 0; y <= 5; y++) {
        blocks.push({ x: 0, y, z: 4, block: LOG });
        // Ladder on front of trunk
        blocks.push({ x: 0, y, z: 3, block: L });
    }

    // Platform at y=6: 5x5
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 6, z, block: W });
        }
    }

    // Fence railing around platform at y=7
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            const isEdge = x === -2 || x === 2 || z === 2 || z === 6;
            if (!isEdge) continue;
            if (z === 2 && x === 0) continue; // entrance
            blocks.push({ x, y: 7, z, block: F });
        }
    }

    // Roof: leaves canopy at y=9
    for (let x = -3; x <= 3; x++) {
        for (let z = 1; z <= 7; z++) {
            blocks.push({ x, y: 9, z, block: LEAF });
        }
    }
    // More leaves at y=10 (smaller)
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 6; z++) {
            blocks.push({ x, y: 10, z, block: LEAF });
        }
    }

    // Torch inside
    blocks.push({ x: 1, y: 8, z: 5, block: T });
    blocks.push({ x: -1, y: 8, z: 5, block: T });

    return blocks;
})();

// Tunnel: 3x3 bore through a hill, 12 blocks long, with torches
export const TUNNEL = (() => {
    const blocks = [];
    const S = 'minecraft:stone_bricks';
    const T = 'minecraft:torch';
    const AIR = 'minecraft:air';

    for (let z = 1; z <= 12; z++) {
        // Clear 3x3 interior
        for (let x = -1; x <= 1; x++) {
            for (let y = 1; y <= 3; y++) {
                blocks.push({ x, y, z, block: AIR });
            }
        }
        // Floor
        blocks.push({ x: -1, y: 0, z, block: S });
        blocks.push({ x: 0, y: 0, z, block: S });
        blocks.push({ x: 1, y: 0, z, block: S });
        // Arch frame on edges
        blocks.push({ x: -2, y: 1, z, block: S });
        blocks.push({ x: -2, y: 2, z, block: S });
        blocks.push({ x: -2, y: 3, z, block: S });
        blocks.push({ x: 2, y: 1, z, block: S });
        blocks.push({ x: 2, y: 2, z, block: S });
        blocks.push({ x: 2, y: 3, z, block: S });
        blocks.push({ x: -1, y: 4, z, block: S });
        blocks.push({ x: 0, y: 4, z, block: S });
        blocks.push({ x: 1, y: 4, z, block: S });

        // Torches every 4 blocks
        if (z % 4 === 0) {
            blocks.push({ x: -1, y: 3, z, block: T });
            blocks.push({ x: 1, y: 3, z, block: T });
        }
    }
    return blocks;
})();

// Garden: flowers, path, and a little pond
export const GARDEN = (() => {
    const blocks = [];
    const PATH = 'minecraft:grass_path';
    const WATER = 'minecraft:water';
    const flowers = [
        'minecraft:poppy', 'minecraft:dandelion', 'minecraft:blue_orchid',
        'minecraft:oxeye_daisy', 'minecraft:cornflower', 'minecraft:allium',
        'minecraft:azure_bluet', 'minecraft:red_tulip', 'minecraft:pink_tulip',
    ];

    // Winding path
    const pathBlocks = [
        [0,2],[0,3],[0,4],[1,5],[1,6],[0,7],[0,8],[-1,9],[-1,10],[0,11]
    ];
    for (const [x, z] of pathBlocks) {
        blocks.push({ x, y: 0, z, block: PATH });
        blocks.push({ x: x+1, y: 0, z, block: PATH });
    }

    // Flowers on both sides of path
    let fi = 0;
    for (const [px, pz] of pathBlocks) {
        blocks.push({ x: px - 2, y: 1, z: pz, block: flowers[fi % flowers.length] });
        blocks.push({ x: px + 3, y: 1, z: pz, block: flowers[(fi+3) % flowers.length] });
        fi++;
    }

    // Small pond at the end (2x3)
    for (let x = -1; x <= 1; x++) {
        for (let z = 12; z <= 13; z++) {
            blocks.push({ x, y: -1, z, block: WATER });
        }
    }

    return blocks;
})();

// Playground: fence enclosure with colored wool blocks to jump on
export const PLAYGROUND = (() => {
    const blocks = [];
    const F = 'minecraft:oak_fence';
    const T = 'minecraft:torch';
    const woolColors = [
        'minecraft:red_wool', 'minecraft:orange_wool', 'minecraft:yellow_wool',
        'minecraft:lime_wool', 'minecraft:light_blue_wool', 'minecraft:pink_wool',
        'minecraft:magenta_wool', 'minecraft:purple_wool',
    ];

    // Fence perimeter 8x8
    for (let x = -4; x <= 4; x++) {
        blocks.push({ x, y: 1, z: 2, block: F });
        blocks.push({ x, y: 1, z: 10, block: F });
    }
    for (let z = 2; z <= 10; z++) {
        blocks.push({ x: -4, y: 1, z, block: F });
        blocks.push({ x: 4, y: 1, z, block: F });
    }

    // Entrance gap
    // (z=2, x=0 is open — no fence there)

    // Colored wool blocks at different heights to jump on
    const jumpBlocks = [
        [-2, 1, 4], [-1, 2, 5], [0, 3, 6], [1, 2, 7], [2, 1, 8],
        [-3, 1, 7], [3, 1, 5], [0, 1, 4], [-2, 2, 8], [1, 1, 4],
        [0, 2, 9], [-1, 1, 6], [2, 3, 6], [-3, 2, 5],
    ];
    let ci = 0;
    for (const [x, y, z] of jumpBlocks) {
        blocks.push({ x, y, z, block: woolColors[ci % woolColors.length] });
        ci++;
    }

    // Torches on fence corners
    blocks.push({ x: -4, y: 2, z: 2, block: T });
    blocks.push({ x: 4, y: 2, z: 2, block: T });
    blocks.push({ x: -4, y: 2, z: 10, block: T });
    blocks.push({ x: 4, y: 2, z: 10, block: T });

    return blocks;
})();

// Rainbow arch in the sky! Stained glass arc, 30 blocks tall
export const RAINBOW = (() => {
    const blocks = [];
    const colors = [
        'minecraft:red_stained_glass',
        'minecraft:orange_stained_glass',
        'minecraft:yellow_stained_glass',
        'minecraft:lime_stained_glass',
        'minecraft:light_blue_stained_glass',
        'minecraft:blue_stained_glass',
        'minecraft:purple_stained_glass',
    ];

    // Arc from left to right using a semicircle
    // Each color band is a slightly smaller arc
    for (let ci = 0; ci < colors.length; ci++) {
        const radius = 30 - ci * 2;
        const block = colors[ci];
        // Draw semicircle arc from -radius to +radius on x axis, arching up on y
        for (let angle = 0; angle <= 180; angle += 3) {
            const rad = (angle * Math.PI) / 180;
            const x = Math.round(Math.cos(rad) * radius);
            const y = Math.round(Math.sin(rad) * radius) + 10; // lift base 10 blocks up
            blocks.push({ x, y, z: 5, block });
        }
    }

    // Glowstone at the two base "pots of gold"
    for (let y = 8; y <= 12; y++) {
        blocks.push({ x: -30, y, z: 5, block: 'minecraft:glowstone' });
        blocks.push({ x: 30, y, z: 5, block: 'minecraft:glowstone' });
    }
    // Gold blocks at the feet
    blocks.push({ x: -30, y: 7, z: 5, block: 'minecraft:gold_block' });
    blocks.push({ x: -29, y: 7, z: 5, block: 'minecraft:gold_block' });
    blocks.push({ x: 30, y: 7, z: 5, block: 'minecraft:gold_block' });
    blocks.push({ x: 29, y: 7, z: 5, block: 'minecraft:gold_block' });

    return blocks;
})();

// Giant Sheep Hotel — the outside looks like an actual sheep!
// Body is white wool (hotel rooms inside), dark legs, cute face with eyes and mouth
export const SHEEP = (() => {
    const blocks = [];
    const W = 'minecraft:white_wool';       // fluffy body
    const DW = 'minecraft:light_gray_wool'; // darker fluff accents
    const LEG = 'minecraft:brown_wool';     // legs
    const FACE = 'minecraft:white_concrete'; // smooth face
    const EYE = 'minecraft:black_wool';     // eyes
    const NOSE = 'minecraft:pink_wool';     // nose/mouth
    const FLOOR = 'minecraft:oak_planks';   // interior floors
    const G = 'minecraft:glass';            // windows
    const T = 'minecraft:torch';
    const L = 'minecraft:lantern';
    const CARPET = 'minecraft:red_carpet';
    const BED_R = 'minecraft:red_wool';     // beds (wool blocks)
    const BED_W = 'minecraft:white_wool';
    const DOOR = 'minecraft:oak_door';
    const STAIR = 'minecraft:oak_stairs';

    // === BODY: 16 wide (x), 10 tall (y), 20 long (z) ===
    // Rounded oval shape — wider in middle, narrower at ends
    // Body starts at y=5 (above legs), z=4 to z=23
    const bodyCenter = { x: 0, z: 14 };
    const bodyRadiusX = 8;  // half width
    const bodyRadiusZ = 10; // half length
    const bodyBottom = 5;
    const bodyTop = 14;

    // Build the wool shell (hollow inside for hotel rooms)
    for (let y = bodyBottom; y <= bodyTop; y++) {
        // Vertical radius varies — wider in middle, narrower top/bottom
        const yNorm = (y - bodyBottom) / (bodyTop - bodyBottom); // 0 to 1
        const yScale = Math.sin(yNorm * Math.PI); // 0->1->0
        const rxAtY = Math.floor(bodyRadiusX * (0.5 + 0.5 * yScale));
        const rzAtY = Math.floor(bodyRadiusZ * (0.5 + 0.5 * yScale));

        for (let x = -rxAtY; x <= rxAtY; x++) {
            for (let z = bodyCenter.z - rzAtY; z <= bodyCenter.z + rzAtY; z++) {
                // Check if on the surface of the ellipsoid
                const dx = x / rxAtY;
                const dz = (z - bodyCenter.z) / rzAtY;
                const dist = dx * dx + dz * dz;

                if (dist <= 1.0 && dist > 0.7) {
                    // Shell — outer surface
                    // Add some darker wool patches for fluffy look
                    const fluffy = Math.sin(x * 3.7 + z * 2.1 + y * 1.3) > 0.6;
                    blocks.push({ x, y, z, block: fluffy ? DW : W });
                } else if (dist <= 0.7 && y === bodyBottom) {
                    // Interior floor
                    blocks.push({ x, y, z, block: FLOOR });
                } else if (dist <= 0.7 && y === bodyBottom + 4) {
                    // Second floor
                    blocks.push({ x, y, z, block: FLOOR });
                }
            }
        }
    }

    // === FOUR LEGS: dark brown, 5 blocks tall each ===
    const legPositions = [
        { x: -5, z: 7 },   // front left
        { x: 5, z: 7 },    // front right
        { x: -5, z: 21 },  // back left
        { x: 5, z: 21 },   // back right
    ];
    for (const leg of legPositions) {
        for (let y = 0; y < 5; y++) {
            for (let dx = -1; dx <= 1; dx++) {
                for (let dz = -1; dz <= 1; dz++) {
                    blocks.push({ x: leg.x + dx, y, z: leg.z + dz, block: LEG });
                }
            }
        }
    }

    // === HEAD: extends forward from body (z=2 to z=6) ===
    // Head is 6x6x6, smooth white concrete face
    const headCenter = { x: 0, z: 3 };
    for (let y = 6; y <= 12; y++) {
        for (let x = -3; x <= 3; x++) {
            for (let z = 0; z <= 6; z++) {
                const isEdge = x === -3 || x === 3 || z === 0 || z === 6 || y === 6 || y === 12;
                if (isEdge) {
                    blocks.push({ x, y, z, block: FACE });
                }
            }
        }
    }

    // Fluffy wool on top of head
    for (let x = -3; x <= 3; x++) {
        for (let z = 1; z <= 5; z++) {
            blocks.push({ x, y: 13, z, block: W });
        }
    }
    for (let x = -2; x <= 2; x++) {
        for (let z = 2; z <= 4; z++) {
            blocks.push({ x, y: 14, z, block: W });
        }
    }

    // Eyes on the front face (z=0)
    blocks.push({ x: -2, y: 10, z: 0, block: EYE });
    blocks.push({ x: -2, y: 11, z: 0, block: EYE });
    blocks.push({ x: 2, y: 10, z: 0, block: EYE });
    blocks.push({ x: 2, y: 11, z: 0, block: EYE });
    // White eye highlights
    blocks.push({ x: -2, y: 11, z: -1, block: W }); // eyebrow fluff
    blocks.push({ x: 2, y: 11, z: -1, block: W });

    // Nose/mouth
    blocks.push({ x: -1, y: 8, z: 0, block: NOSE });
    blocks.push({ x: 0, y: 8, z: 0, block: NOSE });
    blocks.push({ x: 1, y: 8, z: 0, block: NOSE });
    blocks.push({ x: 0, y: 7, z: 0, block: NOSE }); // little smile

    // Ears (wool sticking out sides of head)
    for (let dz = 2; dz <= 4; dz++) {
        blocks.push({ x: -4, y: 11, z: dz, block: W });
        blocks.push({ x: -5, y: 11, z: dz, block: NOSE }); // pink inner ear
        blocks.push({ x: 4, y: 11, z: dz, block: W });
        blocks.push({ x: 5, y: 11, z: dz, block: NOSE });
    }

    // === TAIL: small puff at the back ===
    for (let x = -1; x <= 1; x++) {
        for (let y = 10; y <= 12; y++) {
            blocks.push({ x, y, z: 25, block: W });
        }
    }
    blocks.push({ x: 0, y: 11, z: 26, block: W });

    // === DOOR: entrance in the front of the body (between front legs) ===
    blocks.push({ x: 0, y: 5, z: 4, block: DOOR });

    // === INTERIOR: Hotel rooms! ===
    // Ground floor lobby
    blocks.push({ x: 0, y: 6, z: 8, block: L });   // lobby chandelier
    blocks.push({ x: 0, y: 6, z: 12, block: L });
    // Red carpet in lobby
    for (let z = 5; z <= 14; z++) {
        blocks.push({ x: -1, y: 5, z, block: CARPET });
        blocks.push({ x: 0, y: 5, z, block: CARPET });
        blocks.push({ x: 1, y: 5, z, block: CARPET });
    }

    // Ground floor rooms (left and right of lobby)
    // Left rooms
    for (let roomZ = 8; roomZ <= 18; roomZ += 5) {
        blocks.push({ x: -4, y: 6, z: roomZ, block: BED_R });     // bed
        blocks.push({ x: -4, y: 6, z: roomZ + 1, block: BED_W }); // pillow
        blocks.push({ x: -5, y: 7, z: roomZ, block: T });          // torch
    }
    // Right rooms
    for (let roomZ = 8; roomZ <= 18; roomZ += 5) {
        blocks.push({ x: 4, y: 6, z: roomZ, block: BED_R });
        blocks.push({ x: 4, y: 6, z: roomZ + 1, block: BED_W });
        blocks.push({ x: 5, y: 7, z: roomZ, block: T });
    }

    // Staircase in center
    for (let i = 0; i < 4; i++) {
        blocks.push({ x: 2, y: 6 + i, z: 16 + i, block: STAIR });
    }

    // Second floor rooms
    for (let roomZ = 8; roomZ <= 16; roomZ += 4) {
        blocks.push({ x: -3, y: 10, z: roomZ, block: BED_R });
        blocks.push({ x: -3, y: 10, z: roomZ + 1, block: BED_W });
        blocks.push({ x: -3, y: 11, z: roomZ, block: T });
        blocks.push({ x: 3, y: 10, z: roomZ, block: BED_R });
        blocks.push({ x: 3, y: 10, z: roomZ + 1, block: BED_W });
        blocks.push({ x: 3, y: 11, z: roomZ, block: T });
    }
    // Second floor lanterns
    blocks.push({ x: 0, y: 13, z: 10, block: L });
    blocks.push({ x: 0, y: 13, z: 16, block: L });

    // Windows on the body (glass replacing some wool)
    for (let roomZ = 8; roomZ <= 18; roomZ += 5) {
        // Left side windows
        blocks.push({ x: -8, y: 7, z: roomZ, block: G });
        blocks.push({ x: -8, y: 8, z: roomZ, block: G });
        // Right side windows
        blocks.push({ x: 8, y: 7, z: roomZ, block: G });
        blocks.push({ x: 8, y: 8, z: roomZ, block: G });
    }

    // Welcome sign: gold blocks above door
    blocks.push({ x: -1, y: 11, z: 4, block: 'minecraft:gold_block' });
    blocks.push({ x: 0, y: 11, z: 4, block: 'minecraft:gold_block' });
    blocks.push({ x: 1, y: 11, z: 4, block: 'minecraft:gold_block' });
    blocks.push({ x: 0, y: 12, z: 4, block: L });

    return blocks;
})();

/**
 * Map of chat trigger words to templates.
 */
export const TEMPLATES = {
    house: HOUSE,
    wall: WALL,
    bridge: BRIDGE,
    farm: FARM,
    tower: TOWER,
    treehouse: TREEHOUSE,
    tunnel: TUNNEL,
    garden: GARDEN,
    playground: PLAYGROUND,
    rainbow: RAINBOW,
    sheep: SHEEP,
};
