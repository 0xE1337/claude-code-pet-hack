# Claude Code Buddy Hack

[中文](./README.md)

Reverse-engineer and customize your Claude Code terminal companion (Buddy).

> Claude Code has a hidden pet system — each account gets a deterministic companion generated from your account ID. This project documents the full generation algorithm and provides a one-command patch script to customize your buddy.

[中文版](./README.zh.md)

## Disclaimer

This project is for **educational and entertainment purposes only**. It is not affiliated with, endorsed by, or associated with Anthropic in any way.

- This tool modifies local files installed on your machine. **Use at your own risk.**
- Claude Code updates (`npm update -g @anthropic-ai/claude-code`) will **overwrite the patch** — you'll need to re-run the script after each update.
- The buddy/companion system is purely cosmetic and has no effect on Claude Code's functionality.
- While the risk of account action is extremely low (all changes are local, no data is sent to servers), **no guarantees are made**.
- The minified function/variable names change between versions. The patch script uses pattern matching, but may need updates for future versions.

**By using this tool, you accept full responsibility for any consequences.**

## What is Claude Code Buddy?

Type `/buddy` in Claude Code to see your companion. Each buddy has:

- **Species** — 18 types (Dragon, Cat, Duck, Axolotl, Mushroom, etc.)
- **Rarity** — Common (60%) → Uncommon (25%) → Rare (10%) → Epic (4%) → Legendary (1%)
- **Shiny** — 1% chance of rainbow glow effect
- **Stats** — DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK (0-100)
- **Hat** — crown, tophat, wizard, halo, propeller, beanie, tinyduck
- **Eyes** — `·` `✦` `×` `◉` `@` `°`

The rarest combination is **Shiny Legendary** — 1 in 10,000 chance.

## Quick Start

### Method 1: Rehatch (Recommended)

Browse the [Buddy Dex](https://claude-buddy-dex-cf.zeke-chin.workers.dev/) to find a buddy you like, then rehatch with its user_id. This gives you an **official API-generated name and personality**.

```bash
# Step 1: Browse available buddies
./patch.sh --browse --species dragon --rarity legendary --shiny

# Step 2: Pick one and start rehatch
./patch.sh --rehatch <user_id>

# Step 3: Restart Claude Code, type /buddy to trigger hatching
#         ⚠️ If you added --lang zh, the buddy will appear in English — this is normal
#         Official hatching only generates English; translation happens in the next step
#         After hatching animation completes, close Claude Code

# Step 4: Finalize (all optional flags take effect in this step)
./patch.sh --finish-rehatch

# Step 5: Restart Claude Code again, type /buddy to see the final result ✅
```

Optional flags for Step 2 (add as needed, none are required):

| Flag | Effect | Example |
|------|--------|---------|
| `--stats max` | Max all 5 stats to 100 | `./patch.sh --rehatch <id> --stats max` |
| `--stats D,P,C,W,S` | Custom stat values (DEBUGGING,PATIENCE,CHAOS,WISDOM,SNARK) | `./patch.sh --rehatch <id> --stats 90,80,70,100,85` |
| `--lang zh` | Translate official description to Chinese | `./patch.sh --rehatch <id> --lang zh` |
| `--name "name"` | Rename your buddy | `./patch.sh --rehatch <id> --name "DragonFire"` |

All options combined:

```bash
./patch.sh --rehatch 7173a7ad... --stats max --lang zh --name "DragonFire"
```

### Method 2: Switch Language

Translate the official English personality to Chinese (uses Claude CLI for translation):

```bash
# Switch to Chinese (both card description and bubble chat)
./patch.sh --lang zh

# Switch back to English
./patch.sh --lang en
```

Rename your buddy:

```bash
./patch.sh --name "DragonFire"
```

### Method 3: Stats Only

Keep your original buddy, just max out all stats:

```bash
./patch.sh --stats-only
```

### Method 4: Legacy (Direct Patch)

Directly override species/rarity/shiny without official name generation:

```bash
./patch.sh --legacy --species cat --rarity epic --no-shiny
```

### Restore

```bash
./patch.sh --restore
```

## How It Works

### Generation Pipeline

```
Account UUID + "friend-2026-401"
    → FNV-1a hash
    → Mulberry32 PRNG seed
    → Deterministic: species, rarity, eyes, hat, shiny, stats
```

Your account always generates the same buddy. The only way to change it is to patch the generation function in `cli.js`.

### Rarity Table

| Rarity | Chance | Base Stats | Color | Stars |
|--------|--------|-----------|-------|-------|
| Common | 60% | 5 | Gray | ★ |
| Uncommon | 25% | 15 | Green | ★★ |
| Rare | 10% | 25 | Blue | ★★★ |
| Epic | 4% | 35 | Purple | ★★★★ |
| Legendary | 1% | 50 | Gold | ★★★★★ |

### Stats Generation

Each buddy has one **strong stat** and one **weak stat**, randomly chosen:

- Strong: `base + 50 + random(0-30)`, capped at 100
- Weak: `base - 10 + random(0-15)`, minimum 1
- Others: `base + random(0-40)`

### Species (18 total)

duck, goose, blob, cat, dragon, octopus, owl, penguin,
turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

### Data Storage

User-editable fields are stored in `~/.claude/.claude.json`:

```json
{
  "companion": {
    "name": "Siltwick",
    "personality": "A condescending toadstool who...",
    "hatchedAt": 1775017402675
  }
}
```

The `bones` (species, rarity, stats, etc.) are generated at runtime from the code — not stored in JSON.

## Manual Patch Guide

If you prefer to do it yourself instead of using the script:

### 1. Find cli.js

```bash
# npm global install
CLI_JS="$(npm root -g)/@anthropic-ai/claude-code/cli.js"

# or find it manually
find ~/.nvm -name "cli.js" -path "*claude-code*" 2>/dev/null
```

### 2. Backup

```bash
cp "$CLI_JS" "${CLI_JS}.backup"
```

### 3. Locate the generation function

The function name changes between versions, but the signature is stable:

```bash
grep -oE 'function [A-Za-z_$]+\(q\)\{let K=[A-Za-z_$]+\(q\);return\{bones:\{rarity:K' "$CLI_JS"
```

### 4. Patch

**Full patch (Shiny Legendary + max stats):**

Find the species variable for dragon:
```bash
# Species are encoded as char codes. Find the dragon variable:
grep -oE '[A-Za-z0-9_$]+=JD\(100,114,97,103,111,110\)' "$CLI_JS"
# e.g., IG8=JD(100,114,97,103,111,110) means IG8 = "dragon"
```

Then replace the generation function (example for v2.1.x where function is `Zk_` and dragon is `IG8`):

```bash
sed -i.bak 's/function Zk_(q){let K=Pk_(q);return{bones:{rarity:K,species:\$T6(q,uq4),eye:\$T6(q,mq4),hat:K==="common"?"none":\$T6(q,pq4),shiny:q()<0.01,stats:Dk_(q,K)}/function Zk_(q){let K="legendary";return{bones:{rarity:K,species:IG8,eye:"✦",hat:"crown",shiny:true,stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}}/' "$CLI_JS"
```

**Stats-only patch (keep original species/rarity):**

```bash
sed -i.bak 's/stats:Dk_(q,K)/stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}/' "$CLI_JS"
```

### 5. Verify

```bash
grep -o 'function Zk_(q){[^}]*}' "$CLI_JS" | head -1
```

### 6. Restart Claude Code

Close and reopen Claude Code, then type `/buddy` to see the result.

### 7. Restore

```bash
cp "${CLI_JS}.backup" "$CLI_JS"
```

## Reverse Engineering Details

See [INTERNALS.md](./INTERNALS.md) for the full deobfuscated source code of the buddy system, including:

- FNV-1a hash implementation
- Mulberry32 PRNG
- Species/rarity/stats generation logic
- ASCII art rendering system

## Known Limitations

| Issue | Impact | Workaround |
|-------|--------|------------|
| Claude Code updates overwrite patch | Patch lost after `npm update` | Re-run `./patch.sh` after each update |
| Minified function names change between versions | Script may fail to locate target function | Script uses structural pattern matching; update script if it fails |
| No server-side persistence | Buddy data is generated client-side only | This is actually a feature — no server validation means no ban risk |

## FAQ

**Will this get my account banned?**

Extremely unlikely. The buddy system is purely cosmetic and runs entirely client-side. No buddy data is sent to Anthropic's servers for validation. However, this is not guaranteed — use at your own risk.

**Will it survive updates?**

No. Running `npm update -g @anthropic-ai/claude-code` or automatic updates will overwrite the patch. Re-run `./patch.sh` after updating.

**Function names changed after update?**

The minified function names (like `Zk_`, `Dk_`, `IG8`) change between versions. The patch script uses structural pattern matching (matching the function body shape, not the name) to locate the target. If a major refactor changes the function structure, the script will need updating.

**Is this legal?**

This tool modifies files installed locally on your own machine for personal use. It does not distribute modified Anthropic code. However, always review the relevant Terms of Service yourself.

## Credits

- [Claude Buddy Dex](https://claude-buddy-dex-cf.zeke-chin.workers.dev/) by [@zeke-chin](https://github.com/zeke-chin) — Full buddy collection with searchable filters. Our `--browse` command queries their API.
- [linux.do](https://linux.do) community — For discovering the userid-swap method for buddy rehatch.

## License

MIT — see [LICENSE](./LICENSE)
