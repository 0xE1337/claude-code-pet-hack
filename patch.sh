#!/usr/bin/env bash
set -euo pipefail

# Claude Code Buddy Patcher v2.0.0
# Customize your Claude Code terminal companion

VERSION="2.0.0"
DEX_API="https://claude-buddy-dex-cf.zeke-chin.workers.dev/api"

# --- Defaults ---
SPECIES=""
RARITY=""
SHINY=""
HAT=""
EYE=""
STATS_MAX=false
STATS_ONLY=false
RESTORE=false
REHATCH=false
USER_ID=""
BROWSE=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GOLD='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<EOF
Claude Code Buddy Patcher v${VERSION}

Usage: ./patch.sh [MODE] [OPTIONS]

Modes:
  ./patch.sh --rehatch <user_id>     Switch to a different buddy with official API-generated
                                     name and personality (recommended method)
  ./patch.sh --browse                Browse the buddy dex to find your dream companion
  ./patch.sh --stats-only            Only max out stats, keep everything else
  ./patch.sh --restore               Restore original cli.js from backup

Rehatch Options (use with --rehatch):
  --stats max                        Also max out all stats to 100 after rehatch

Browse Options (use with --browse):
  --species <name>                   Filter by species
  --rarity <level>                   Filter by rarity
  --shiny                            Filter shiny only

Legacy Mode (direct bones patch, no official name/personality):
  ./patch.sh --legacy [OPTIONS]      Patch bones directly without rehatch

Legacy Options:
  --species <name>    Set species (default: dragon)
                      Available: duck, goose, blob, cat, dragon, octopus, owl,
                      penguin, turtle, snail, ghost, axolotl, capybara, cactus,
                      robot, rabbit, mushroom, chonk
  --rarity <level>    Set rarity (default: legendary)
                      Available: common, uncommon, rare, epic, legendary
  --shiny / --no-shiny
  --hat <name>        Available: none, crown, tophat, propeller, halo, wizard, beanie, tinyduck
  --eye <char>        Available: · ✦ × ◉ @ °
  --stats max|keep    Set all stats to 100 or keep original

Examples:
  ./patch.sh --browse --species dragon --rarity legendary --shiny
  ./patch.sh --rehatch 7173a7ad...
  ./patch.sh --rehatch 7173a7ad... --stats max
  ./patch.sh --stats-only
  ./patch.sh --restore
  ./patch.sh --legacy --species cat --rarity epic
EOF
  exit 0
}

LEGACY=false

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --rehatch) REHATCH=true; USER_ID="$2"; shift 2 ;;
    --browse) BROWSE=true; shift ;;
    --legacy) LEGACY=true; shift ;;
    --species) SPECIES="$2"; shift 2 ;;
    --rarity) RARITY="$2"; shift 2 ;;
    --shiny) SHINY="true"; shift ;;
    --no-shiny) SHINY="false"; shift ;;
    --hat) HAT="$2"; shift 2 ;;
    --eye) EYE="$2"; shift 2 ;;
    --stats)
      if [[ "$2" == "max" ]]; then STATS_MAX=true; else STATS_MAX=false; fi
      shift 2 ;;
    --stats-only) STATS_ONLY=true; shift ;;
    --restore) RESTORE=true; shift ;;
    --help|-h) usage ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
  esac
done

# --- Find cli.js ---
find_cli_js() {
  local npm_root
  npm_root="$(npm root -g 2>/dev/null)" || true
  if [[ -f "${npm_root}/@anthropic-ai/claude-code/cli.js" ]]; then
    echo "${npm_root}/@anthropic-ai/claude-code/cli.js"
    return
  fi

  local claude_bin
  claude_bin="$(which claude 2>/dev/null)" || true
  if [[ -n "$claude_bin" ]]; then
    local real_path
    real_path="$(readlink -f "$claude_bin" 2>/dev/null || readlink "$claude_bin" 2>/dev/null)" || true
    local dir
    dir="$(dirname "$real_path" 2>/dev/null)" || true
    if [[ -f "${dir}/cli.js" ]]; then
      echo "${dir}/cli.js"
      return
    fi
  fi

  local nvm_path
  for nvm_path in ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js; do
    if [[ -f "$nvm_path" ]]; then
      echo "$nvm_path"
      return
    fi
  done

  echo ""
}

CLI_JS="$(find_cli_js)"

if [[ -z "$CLI_JS" ]]; then
  echo -e "${RED}Error: Could not find Claude Code cli.js${NC}"
  echo "Make sure Claude Code is installed: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

echo -e "${BLUE}Found cli.js:${NC} $CLI_JS"

CLAUDE_JSON="$HOME/.claude.json"

# ============================================================
# MODE: Restore
# ============================================================
if [[ "$RESTORE" == "true" ]]; then
  if [[ -f "${CLI_JS}.backup" ]]; then
    cp "${CLI_JS}.backup" "$CLI_JS"
    echo -e "${GREEN}cli.js restored from backup.${NC}"
  else
    echo -e "${YELLOW}No cli.js backup found (already original).${NC}"
  fi
  if [[ -f "${CLAUDE_JSON}.buddy-backup" ]]; then
    cp "${CLAUDE_JSON}.buddy-backup" "$CLAUDE_JSON"
    echo -e "${GREEN}.claude.json restored from backup.${NC}"
  fi
  exit 0
fi

# ============================================================
# MODE: Browse dex
# ============================================================
if [[ "$BROWSE" == "true" ]]; then
  if ! command -v curl &>/dev/null; then
    echo -e "${RED}curl is required for --browse${NC}"
    exit 1
  fi

  QUERY="limit=10&offset=0"
  [[ -n "$SPECIES" ]] && QUERY="${QUERY}&species=${SPECIES}"
  [[ -n "$RARITY" ]] && QUERY="${QUERY}&rarity=${RARITY}"
  [[ "$SHINY" == "true" ]] && QUERY="${QUERY}&shiny=1"

  echo -e "${BLUE}Fetching from buddy dex...${NC}"
  RESULT=$(curl -s "${DEX_API}/buddies?${QUERY}")

  TOTAL=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])" 2>/dev/null || echo "0")
  echo -e "${GREEN}Found ${TOTAL} buddies matching your criteria${NC}"
  echo ""

  echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for i, b in enumerate(data.get('buddies', []), 1):
    stats = b['stats']
    total = sum(stats.values())
    shiny = ' ✨SHINY' if b['shiny'] else ''
    print(f\"  {i}. {b['rarity'].upper()} {b['species'].upper()}{shiny}  hat={b['hat']} eye={b['eye']}  total_stats={total}\")
    print(f\"     user_id={b['user_id']}\")
    print()
" 2>/dev/null

  echo -e "${YELLOW}To use a buddy: ./patch.sh --rehatch <user_id>${NC}"
  echo -e "${YELLOW}Add --stats max to also max out all stats${NC}"
  exit 0
fi

# ============================================================
# MODE: Rehatch (recommended)
# ============================================================
if [[ "$REHATCH" == "true" ]]; then
  if [[ -z "$USER_ID" ]]; then
    echo -e "${RED}Usage: ./patch.sh --rehatch <user_id>${NC}"
    echo "Find user_ids with: ./patch.sh --browse --species dragon --rarity legendary --shiny"
    exit 1
  fi

  echo -e "${BLUE}Rehatch mode: switching to buddy from user_id${NC}"
  echo -e "${BLUE}user_id:${NC} $USER_ID"

  # Backup
  [[ ! -f "${CLI_JS}.backup" ]] && cp "$CLI_JS" "${CLI_JS}.backup"
  cp "$CLAUDE_JSON" "${CLAUDE_JSON}.buddy-backup"
  echo -e "${GREEN}Backups created${NC}"

  # Find and patch RR1() function
  ORIG_RR1=$(grep -o 'function RR1(){[^}]*}' "$CLI_JS" | head -1)
  if [[ -z "$ORIG_RR1" ]]; then
    echo -e "${RED}Could not find RR1() function in cli.js${NC}"
    exit 1
  fi

  REPL_RR1="function RR1(){return \"${USER_ID}\"}"

  perl -i -pe "
    BEGIN {
      \$orig = q|${ORIG_RR1}|;
      \$repl = q|${REPL_RR1}|;
    }
    s/\Q\$orig\E/\$repl/
  " "$CLI_JS"

  echo -e "${GREEN}RR1() patched to return target user_id${NC}"

  # Delete companion to trigger rehatch
  python3 -c "
import json
f = '$CLAUDE_JSON'
data = json.load(open(f))
if 'companion' in data:
    del data['companion']
    json.dump(data, open(f, 'w'), ensure_ascii=False)
    print('Companion data cleared')
else:
    print('No existing companion (clean)')
"

  echo ""
  echo -e "${GOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GOLD}║  Now restart Claude Code and type /buddy         ║${NC}"
  echo -e "${GOLD}║  to trigger hatching with official API name.     ║${NC}"
  echo -e "${GOLD}║                                                  ║${NC}"
  echo -e "${GOLD}║  After hatching, run:                            ║${NC}"
  echo -e "${GOLD}║    ./patch.sh --finish-rehatch                   ║${NC}"
  if [[ "$STATS_MAX" == "true" ]]; then
  echo -e "${GOLD}║                                                  ║${NC}"
  echo -e "${GOLD}║  Stats will be maxed out in the finish step.     ║${NC}"
  fi
  echo -e "${GOLD}╚══════════════════════════════════════════════════╝${NC}"

  # Save state for --finish-rehatch
  echo "$USER_ID" > "${CLI_JS}.rehatch-state"
  [[ "$STATS_MAX" == "true" ]] && echo "stats_max" >> "${CLI_JS}.rehatch-state"

  exit 0
fi

# ============================================================
# MODE: Finish rehatch (restore RR1, optionally max stats)
# ============================================================
if [[ "${1:-}" == "--finish-rehatch" ]] 2>/dev/null || false; then
  true  # handled below
fi

# Check for --finish-rehatch anywhere in args
for arg in "$@" "${1:-}"; do
  if [[ "$arg" == "--finish-rehatch" ]]; then
    if [[ ! -f "${CLI_JS}.backup" ]]; then
      echo -e "${RED}No backup found. Did you run --rehatch first?${NC}"
      exit 1
    fi

    # Restore cli.js
    cp "${CLI_JS}.backup" "$CLI_JS"
    echo -e "${GREEN}cli.js restored (RR1 back to original)${NC}"

    # Check if stats max was requested
    if [[ -f "${CLI_JS}.rehatch-state" ]] && grep -q "stats_max" "${CLI_JS}.rehatch-state" 2>/dev/null; then
      echo -e "${BLUE}Applying max stats...${NC}"
      STATS_FUNC=$(grep -oE 'stats:[A-Za-z_$]+\(q,K\)' "$CLI_JS" | head -1 | sed 's/stats://' | sed 's/(q,K)//')
      if [[ -n "$STATS_FUNC" ]]; then
        sed -i.tmp "s/stats:${STATS_FUNC}(q,K)/stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}/" "$CLI_JS"
        rm -f "${CLI_JS}.tmp"
        echo -e "${GREEN}Stats maxed to 100!${NC}"
      fi
    fi

    rm -f "${CLI_JS}.rehatch-state"

    # Show current companion
    echo ""
    python3 -c "
import json
data = json.load(open('$CLAUDE_JSON'))
comp = data.get('companion', {})
if comp:
    print(f\"  Name:        {comp.get('name', '?')}\")
    print(f\"  Personality: {comp.get('personality', '?')[:80]}...\")
    print()
    print('  Rehatch complete! Your buddy has an official API-generated identity.')
else:
    print('  Warning: No companion data found. Did you run /buddy after --rehatch?')
" 2>/dev/null

    echo ""
    echo -e "${YELLOW}Restart Claude Code to see your new companion!${NC}"
    exit 0
  fi
done

# ============================================================
# MODE: Stats-only
# ============================================================
if [[ "$STATS_ONLY" == "true" ]]; then
  [[ ! -f "${CLI_JS}.backup" ]] && cp "$CLI_JS" "${CLI_JS}.backup"
  [[ -f "${CLI_JS}.backup" ]] && cp "${CLI_JS}.backup" "$CLI_JS"

  STATS_FUNC=$(grep -oE 'stats:[A-Za-z_$]+\(q,K\)' "$CLI_JS" | head -1 | sed 's/stats://' | sed 's/(q,K)//')
  if [[ -z "$STATS_FUNC" ]]; then
    echo -e "${RED}Could not locate stats function.${NC}"
    exit 1
  fi

  sed -i.tmp "s/stats:${STATS_FUNC}(q,K)/stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}/" "$CLI_JS"
  rm -f "${CLI_JS}.tmp"

  echo -e "${GREEN}Stats patched to all 100.${NC}"
  echo -e "${YELLOW}Restart Claude Code and type /buddy to verify.${NC}"
  exit 0
fi

# ============================================================
# MODE: Legacy (direct bones patch)
# ============================================================
if [[ "$LEGACY" != "true" ]]; then
  # No mode specified, show usage
  echo -e "${YELLOW}No mode specified. Use one of:${NC}"
  echo ""
  echo "  ./patch.sh --browse                    # Find a buddy from the dex"
  echo "  ./patch.sh --rehatch <user_id>         # Switch to a buddy with official name"
  echo "  ./patch.sh --stats-only                # Just max out stats"
  echo "  ./patch.sh --legacy                    # Direct patch (no official name)"
  echo "  ./patch.sh --restore                   # Restore original"
  echo "  ./patch.sh --help                      # Full help"
  exit 0
fi

# Legacy mode defaults
[[ -z "$SPECIES" ]] && SPECIES="dragon"
[[ -z "$RARITY" ]] && RARITY="legendary"
[[ -z "$SHINY" ]] && SHINY="true"
[[ -z "$HAT" ]] && HAT="crown"
[[ -z "$EYE" ]] && EYE="✦"

# --- Backup ---
if [[ ! -f "${CLI_JS}.backup" ]]; then
  cp "$CLI_JS" "${CLI_JS}.backup"
  echo -e "${GREEN}Backup created.${NC}"
else
  cp "${CLI_JS}.backup" "$CLI_JS"
  echo -e "${YELLOW}Restored from existing backup before re-patching.${NC}"
fi

# --- Find species variable name ---
get_species_code() {
  case "$1" in
    duck)     echo "100,117,99,107" ;;
    goose)    echo "103,111,111,115,101" ;;
    blob)     echo "98,108,111,98" ;;
    cat)      echo "99,97,116" ;;
    dragon)   echo "100,114,97,103,111,110" ;;
    octopus)  echo "111,99,116,111,112,117,115" ;;
    owl)      echo "111,119,108" ;;
    penguin)  echo "112,101,110,103,117,105,110" ;;
    turtle)   echo "116,117,114,116,108,101" ;;
    snail)    echo "115,110,97,105,108" ;;
    ghost)    echo "103,104,111,115,116" ;;
    axolotl)  echo "97,120,111,108,111,116,108" ;;
    capybara) echo "99,97,112,121,98,97,114,97" ;;
    cactus)   echo "99,97,99,116,117,115" ;;
    robot)    echo "114,111,98,111,116" ;;
    rabbit)   echo "114,97,98,98,105,116" ;;
    mushroom) echo "109,117,115,104,114,111,111,109" ;;
    chonk)    echo "99,104,111,110,107" ;;
    *)        echo "" ;;
  esac
}

SPECIES_CODE="$(get_species_code "$SPECIES")"
if [[ -z "$SPECIES_CODE" ]]; then
  echo -e "${RED}Unknown species: $SPECIES${NC}"
  echo "Available: duck goose blob cat dragon octopus owl penguin turtle snail ghost axolotl capybara cactus robot rabbit mushroom chonk"
  exit 1
fi

SPECIES_VAR=$(grep -oE '[A-Za-z0-9_$]+=JD\('"$SPECIES_CODE"'\)' "$CLI_JS" | head -1 | cut -d= -f1)

if [[ -z "$SPECIES_VAR" ]]; then
  echo -e "${RED}Could not find species variable for '$SPECIES' in cli.js${NC}"
  exit 1
fi

echo -e "${BLUE}Species '${SPECIES}' mapped to variable:${NC} $SPECIES_VAR"

# --- Find generation function ---
GEN_FUNC=$(grep -oE 'function [A-Za-z_$]+\(q\)\{let K=[A-Za-z_$]+\(q\);return\{bones:\{rarity:K' "$CLI_JS" | head -1)

if [[ -z "$GEN_FUNC" ]]; then
  echo -e "${RED}Could not locate buddy generation function.${NC}"
  exit 1
fi

FUNC_NAME=$(echo "$GEN_FUNC" | grep -oE 'function [A-Za-z_$]+' | sed 's/function //')
RARITY_FUNC_NAME=$(echo "$GEN_FUNC" | grep -oE 'let K=[A-Za-z_$]+' | sed 's/let K=//')

echo -e "${BLUE}Generation function:${NC} $FUNC_NAME"

# --- Build stats string ---
if [[ "$STATS_MAX" == "true" ]]; then
  STATS_STR="stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}"
else
  STATS_FUNC=$(grep -oE 'stats:[A-Za-z_$]+\(q,K\)' "$CLI_JS" | head -1)
  STATS_STR="$STATS_FUNC"
fi

# --- Patch ---
ORIG_BODY=$(grep -o "function ${FUNC_NAME}(q){[^}]*}" "$CLI_JS" | head -1)

if [[ -z "$ORIG_BODY" ]]; then
  echo -e "${RED}Could not extract function body.${NC}"
  exit 1
fi

REPL_BODY="function ${FUNC_NAME}(q){let K=\"${RARITY}\";return{bones:{rarity:K,species:${SPECIES_VAR},eye:\"${EYE}\",hat:\"${HAT}\",shiny:${SHINY},${STATS_STR}}"

perl -i -pe "
  BEGIN {
    \$orig = q|${ORIG_BODY}|;
    \$repl = q|${REPL_BODY}|;
  }
  s/\Q\$orig\E/\$repl/
" "$CLI_JS"

# --- Verify ---
RESULT=$(grep -o "function ${FUNC_NAME}(q){[^}]*}" "$CLI_JS" | head -1)

if echo "$RESULT" | grep -q "\"${RARITY}\""; then
  echo ""
  echo -e "${GREEN}Patch applied successfully!${NC}"
  echo ""
  echo -e "  Species:  ${BLUE}${SPECIES}${NC}"
  case $RARITY in
    common)    echo -e "  Rarity:   ${NC}★ COMMON${NC}" ;;
    uncommon)  echo -e "  Rarity:   ${GREEN}★★ UNCOMMON${NC}" ;;
    rare)      echo -e "  Rarity:   ${BLUE}★★★ RARE${NC}" ;;
    epic)      echo -e "  Rarity:   ${PURPLE}★★★★ EPIC${NC}" ;;
    legendary) echo -e "  Rarity:   ${GOLD}★★★★★ LEGENDARY${NC}" ;;
  esac
  echo -e "  Shiny:    ${SHINY}"
  echo -e "  Hat:      ${HAT}"
  echo -e "  Eye:      ${EYE}"
  if [[ "$STATS_MAX" == "true" ]]; then
    echo -e "  Stats:    ${GREEN}ALL 100${NC}"
  else
    echo -e "  Stats:    original"
  fi
  echo ""
  echo -e "${YELLOW}Restart Claude Code and type /buddy to see your new companion!${NC}"
else
  echo -e "${RED}Patch may not have applied correctly.${NC}"
  echo "Result: $RESULT"
fi
