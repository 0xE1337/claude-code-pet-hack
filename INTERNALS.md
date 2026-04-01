# Buddy System Internals

Full deobfuscated source code of the Claude Code buddy generation system.

## Core Algorithm

### 1. User ID Retrieval

```javascript
function getUserId() {
  return settings.oauthAccount?.accountUuid ?? settings.userID ?? "anon";
}
```

### 2. FNV-1a Hash

Used to convert the user ID + seed string into a 32-bit integer.

```javascript
function fnv1a(str) {
  let hash = 2166136261;
  for (let i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}
```

### 3. Mulberry32 PRNG

Deterministic pseudo-random number generator. Given the same seed, always produces the same sequence.

```javascript
function mulberry32(seed) {
  let state = seed >>> 0;
  return function () {
    state |= 0;
    state = (state + 1831565813) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
```

### 4. Helper: Pick Random from Array

```javascript
function pickRandom(rng, array) {
  return array[Math.floor(rng() * array.length)];
}
```

### 5. Rarity Selection

Weighted random selection. The RNG call order matters — rarity is determined first.

```javascript
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"];
const RARITY_WEIGHTS = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 };

function pickRarity(rng) {
  const total = Object.values(RARITY_WEIGHTS).reduce((a, b) => a + b, 0); // 100
  let roll = rng() * total;
  for (const rarity of RARITY_ORDER) {
    roll -= RARITY_WEIGHTS[rarity];
    if (roll < 0) return rarity;
  }
  return "common";
}
```

### 6. Stats Generation

```javascript
const STAT_NAMES = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"];
const BASE_STATS = { common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50 };

function generateStats(rng, rarity) {
  const base = BASE_STATS[rarity];

  // Pick one strong stat and one weak stat
  const strongStat = pickRandom(rng, STAT_NAMES);
  let weakStat = pickRandom(rng, STAT_NAMES);
  while (weakStat === strongStat) weakStat = pickRandom(rng, STAT_NAMES);

  const stats = {};
  for (const name of STAT_NAMES) {
    if (name === strongStat) {
      stats[name] = Math.min(100, base + 50 + Math.floor(rng() * 30));
    } else if (name === weakStat) {
      stats[name] = Math.max(1, base - 10 + Math.floor(rng() * 15));
    } else {
      stats[name] = base + Math.floor(rng() * 40);
    }
  }
  return stats;
}
```

### 7. Full Buddy Generation

```javascript
const SPECIES = [
  "duck", "goose", "blob", "cat", "dragon", "octopus", "owl", "penguin",
  "turtle", "snail", "ghost", "axolotl", "capybara", "cactus", "robot",
  "rabbit", "mushroom", "chonk"
];
const EYES = ["·", "✦", "×", "◉", "@", "°"];
const HATS = ["none", "crown", "tophat", "propeller", "halo", "wizard", "beanie", "tinyduck"];

function generateBuddy(rng) {
  const rarity = pickRarity(rng);
  return {
    bones: {
      rarity: rarity,
      species: pickRandom(rng, SPECIES),
      eye: pickRandom(rng, EYES),
      hat: rarity === "common" ? "none" : pickRandom(rng, HATS),
      shiny: rng() < 0.01,
      stats: generateStats(rng, rarity),
    },
    inspirationSeed: Math.floor(rng() * 1e9),
  };
}
```

### 8. Entry Point

```javascript
function createBuddy(userId) {
  const seed = userId + "friend-2026-401";
  const hash = fnv1a(seed);
  const rng = mulberry32(hash);
  return generateBuddy(rng);
}
```

## Display Constants

### Rarity Colors

```javascript
const RARITY_COLORS = {
  common: "inactive",    // gray
  uncommon: "success",   // green
  rare: "permission",    // blue
  epic: "autoAccept",    // purple
  legendary: "warning",  // gold
};
```

### Rarity Stars

```javascript
const RARITY_STARS = {
  common: "★",
  uncommon: "★★",
  rare: "★★★",
  epic: "★★★★",
  legendary: "★★★★★",
};
```

## Minified Variable Mapping (v2.1.x)

These names change between versions. Use the pattern matching in `patch.sh` to locate them dynamically.

| Readable Name | Minified | Description |
|---------------|----------|-------------|
| `generateBuddy` | `Zk_` | Main generation function |
| `pickRarity` | `Pk_` | Rarity selection |
| `generateStats` | `Dk_` | Stats generation |
| `pickRandom` | `$T6` | Random array pick |
| `mulberry32` | `Mk_` | PRNG |
| `fnv1a` | `Xk_` | Hash function |
| `SPECIES` | `uq4` | Species array |
| `EYES` | `mq4` | Eyes array |
| `HATS` | `pq4` | Hats array |
| `STAT_NAMES` | `Mr` | Stat names array |
| `RARITY_WEIGHTS` | `Uh1` | Rarity probability weights |
| `BASE_STATS` | `Wk_` | Base stats per rarity |
| `RARITY_ORDER` | `Iq4` | Rarity order array |
| dragon | `IG8` | `JD(100,114,97,103,111,110)` |

## Species Encoding

Species names are encoded as `String.fromCharCode(...)` calls to avoid easy string searching:

```javascript
// JD = String.fromCharCode
SG8 = JD(100,117,99,107)           // "duck"
CG8 = JD(103,111,111,115,101)      // "goose"
bG8 = JD(98,108,111,98)            // "blob"
xG8 = JD(99,97,116)                // "cat"
IG8 = JD(100,114,97,103,111,110)   // "dragon"
uG8 = JD(111,99,116,111,112,117,115) // "octopus"
mG8 = JD(111,119,108)              // "owl"
pG8 = JD(112,101,110,103,117,105,110) // "penguin"
BG8 = JD(116,117,114,116,108,101)  // "turtle"
gG8 = JD(115,110,97,105,108)       // "snail"
FG8 = JD(103,104,111,115,116)      // "ghost"
UG8 = JD(97,120,111,108,111,116,108) // "axolotl"
QG8 = JD(99,97,112,121,98,97,114,97) // "capybara"
dG8 = JD(99,97,99,116,117,115)     // "cactus"
cG8 = JD(114,111,98,111,116)       // "robot"
lG8 = JD(114,97,98,98,105,116)     // "rabbit"
nG8 = JD(109,117,115,104,114,111,111,109) // "mushroom"
iG8 = JD(99,104,111,110,107)       // "chonk"
```
