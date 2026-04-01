#!/usr/bin/env bash
set -euo pipefail

# Claude Code Buddy Patcher
# Customize your Claude Code terminal companion

VERSION="1.0.0"

# --- Defaults ---
SPECIES="dragon"
RARITY="legendary"
SHINY="true"
HAT="crown"
EYE="✦"
STATS_MAX=true
STATS_ONLY=false
RESTORE=false

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

Usage: ./patch.sh [OPTIONS]

Options:
  --species <name>    Set species (default: dragon)
                      Available: duck, goose, blob, cat, dragon, octopus, owl,
                      penguin, turtle, snail, ghost, axolotl, capybara, cactus,
                      robot, rabbit, mushroom, chonk
  --rarity <level>    Set rarity (default: legendary)
                      Available: common, uncommon, rare, epic, legendary
  --shiny             Enable shiny effect (default: on)
  --no-shiny          Disable shiny effect
  --hat <name>        Set hat (default: crown)
                      Available: none, crown, tophat, propeller, halo, wizard, beanie, tinyduck
  --eye <char>        Set eye character (default: ✦)
                      Available: · ✦ × ◉ @ °
  --stats max         Set all stats to 100 (default)
  --stats keep        Keep original stats generation
  --stats-only        Only patch stats, keep everything else original
  --restore           Restore from backup
  --help              Show this help

Examples:
  ./patch.sh                                          # Shiny Legendary Dragon, all stats 100
  ./patch.sh --species cat --rarity epic --no-shiny   # Epic Cat, no shiny
  ./patch.sh --stats-only                             # Only max stats, keep original pet
  ./patch.sh --restore                                # Restore original
EOF
  exit 0
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --species) SPECIES="$2"; shift 2 ;;
    --rarity) RARITY="$2"; shift 2 ;;
    --shiny) SHINY="true"; shift ;;
    --no-shiny) SHINY="false"; shift ;;
    --hat) HAT="$2"; shift 2 ;;
    --eye) EYE="$2"; shift 2 ;;
    --stats)
      if [[ "$2" == "keep" ]]; then STATS_MAX=false; fi
      shift 2 ;;
    --stats-only) STATS_ONLY=true; shift ;;
    --restore) RESTORE=true; shift ;;
    --help|-h) usage ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
  esac
done

# --- Find cli.js ---
find_cli_js() {
  # Method 1: npm global root
  local npm_root
  npm_root="$(npm root -g 2>/dev/null)" || true
  if [[ -f "${npm_root}/@anthropic-ai/claude-code/cli.js" ]]; then
    echo "${npm_root}/@anthropic-ai/claude-code/cli.js"
    return
  fi

  # Method 2: which claude -> resolve symlink
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

  # Method 3: common nvm paths
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

# --- Restore ---
if [[ "$RESTORE" == "true" ]]; then
  if [[ -f "${CLI_JS}.backup" ]]; then
    cp "${CLI_JS}.backup" "$CLI_JS"
    echo -e "${GREEN}Restored from backup.${NC}"
  else
    echo -e "${RED}No backup found at ${CLI_JS}.backup${NC}"
    exit 1
  fi
  exit 0
fi

# --- Backup ---
if [[ ! -f "${CLI_JS}.backup" ]]; then
  cp "$CLI_JS" "${CLI_JS}.backup"
  echo -e "${GREEN}Backup created.${NC}"
else
  # Always restore from backup before patching to avoid double-patch
  cp "${CLI_JS}.backup" "$CLI_JS"
  echo -e "${YELLOW}Restored from existing backup before re-patching.${NC}"
fi

# --- Stats-only patch ---
if [[ "$STATS_ONLY" == "true" ]]; then
  # Find the stats call pattern: stats:XX_(q,K)
  if grep -q 'stats:Dk_(q,K)' "$CLI_JS" 2>/dev/null; then
    STATS_FUNC="Dk_"
  else
    # Dynamic detection: find function that generates stats with DEBUGGING etc
    STATS_FUNC=$(grep -oE '[A-Za-z_$]+\(q,K\)' "$CLI_JS" | head -1 | sed 's/(q,K)//')
    if [[ -z "$STATS_FUNC" ]]; then
      echo -e "${RED}Could not locate stats function.${NC}"
      exit 1
    fi
  fi

  sed -i.tmp "s/stats:${STATS_FUNC}(q,K)/stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}/" "$CLI_JS"
  rm -f "${CLI_JS}.tmp"

  echo -e "${GREEN}Stats patched to all 100.${NC}"
  echo -e "${YELLOW}Restart Claude Code and type /buddy to verify.${NC}"
  exit 0
fi

# --- Find species variable name ---
# Species are encoded as String.fromCharCode calls
declare -A SPECIES_CODES=(
  [duck]="100,117,99,107"
  [goose]="103,111,111,115,101"
  [blob]="98,108,111,98"
  [cat]="99,97,116"
  [dragon]="100,114,97,103,111,110"
  [octopus]="111,99,116,111,112,117,115"
  [owl]="111,119,108"
  [penguin]="112,101,110,103,117,105,110"
  [turtle]="116,117,114,116,108,101"
  [snail]="115,110,97,105,108"
  [ghost]="103,104,111,115,116"
  [axolotl]="97,120,111,108,111,116,108"
  [capybara]="99,97,112,121,98,97,114,97"
  [cactus]="99,97,99,116,117,115"
  [robot]="114,111,98,111,116"
  [rabbit]="114,97,98,98,105,116"
  [mushroom]="109,117,115,104,114,111,111,109"
  [chonk]="99,104,111,110,107"
)

SPECIES_CODE="${SPECIES_CODES[$SPECIES]:-}"
if [[ -z "$SPECIES_CODE" ]]; then
  echo -e "${RED}Unknown species: $SPECIES${NC}"
  echo "Available: ${!SPECIES_CODES[*]}"
  exit 1
fi

# Find the variable name for this species
SPECIES_VAR=$(grep -oE '[A-Za-z0-9_$]+=JD\('"$SPECIES_CODE"'\)' "$CLI_JS" | head -1 | cut -d= -f1)

if [[ -z "$SPECIES_VAR" ]]; then
  echo -e "${RED}Could not find species variable for '$SPECIES' in cli.js${NC}"
  echo "The code structure may have changed. Try updating this script."
  exit 1
fi

echo -e "${BLUE}Species '${SPECIES}' mapped to variable:${NC} $SPECIES_VAR"

# --- Find generation function ---
GEN_FUNC=$(grep -oE 'function [A-Za-z_$]+\(q\)\{let K=[A-Za-z_$]+\(q\);return\{bones:\{rarity:K' "$CLI_JS" | head -1)

if [[ -z "$GEN_FUNC" ]]; then
  echo -e "${RED}Could not locate buddy generation function.${NC}"
  echo "The code structure may have changed in this version."
  exit 1
fi

# Extract function name
FUNC_NAME=$(echo "$GEN_FUNC" | grep -oE 'function [A-Za-z_$]+' | sed 's/function //')
# Extract rarity function name
RARITY_FUNC=$(echo "$GEN_FUNC" | grep -oE 'let K=[A-Za-z_$]+' | sed 's/let K=//')

echo -e "${BLUE}Generation function:${NC} $FUNC_NAME"
echo -e "${BLUE}Rarity function:${NC} $RARITY_FUNC"

# --- Build stats string ---
if [[ "$STATS_MAX" == "true" ]]; then
  STATS_STR="stats:{DEBUGGING:100,PATIENCE:100,CHAOS:100,WISDOM:100,SNARK:100}"
else
  # Find the original stats function call
  STATS_FUNC=$(grep -oE 'stats:[A-Za-z_$]+\(q,K\)' "$CLI_JS" | head -1)
  STATS_STR="$STATS_FUNC"
fi

# --- Build the original pattern to match ---
# We need to match the full function up to the closing of bones
ORIG_PATTERN="function ${FUNC_NAME}(q){let K=${RARITY_FUNC}(q);return{bones:{rarity:K,species:\$T6(q,uq4),eye:\$T6(q,mq4),hat:K===\"common\"?\"none\":\$T6(q,pq4),shiny:q()<0.01,stats:Dk_(q,K)}"

# Build replacement - note: we keep the rest of the function (inspirationSeed etc) unchanged
REPLACEMENT="function ${FUNC_NAME}(q){let K=\"${RARITY}\";return{bones:{rarity:K,species:${SPECIES_VAR},eye:\"${EYE}\",hat:\"${HAT}\",shiny:${SHINY},${STATS_STR}}"

# --- Apply patch ---
# Use perl for reliable multi-char replacement
perl -i -pe "
  s/\Qfunction ${FUNC_NAME}(q){let K=${RARITY_FUNC}(q);return{bones:{rarity:K,species:\$T6(q,uq4),eye:\$T6(q,mq4),hat:K===\"common\"?\"none\":\$T6(q,pq4),shiny:q()<0.01,stats:Dk_(q,K)}\E/function ${FUNC_NAME}(q){let K=\"${RARITY}\";return{bones:{rarity:K,species:${SPECIES_VAR},eye:\"${EYE}\",hat:\"${HAT}\",shiny:${SHINY},${STATS_STR}}}/
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
  echo ""
  echo "Try restoring and patching again: ./patch.sh --restore && ./patch.sh"
fi
