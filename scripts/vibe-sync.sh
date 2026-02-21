#!/usr/bin/env bash
# vibe-sync — Phone-to-VS-Code bridge
#
# Usage:
#   source scripts/vibe-sync.sh          # run once to set alias + sync
#   vibe-sync                            # use the alias after that
#
# What it does:
#   1. Verifies git identity is iwes247 (not your work user)
#   2. Pulls latest from origin main
#   3. Prints the active-spec.md so Copilot has context
#
# Workflow:
#   Phone (GPT) → edit .github/prompts/active-spec.md → push to main
#   VS Code     → vibe-sync → tell Copilot "read the active spec and do what it says"

set -euo pipefail

SPEC_FILE=".github/prompts/active-spec.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Identity check ──────────────────────────────────────────────────
current_user=$(git config user.name 2>/dev/null || echo "")
current_email=$(git config user.email 2>/dev/null || echo "")

if [[ "$current_user" != "iwes247" ]]; then
    echo -e "${RED}✗ Git user is '${current_user}' — expected 'iwes247'${NC}"
    echo -e "${YELLOW}  Fixing...${NC}"
    git config user.name "iwes247"
    git config user.email "iwes247@users.noreply.github.com"
    echo -e "${GREEN}✓ Set to iwes247 / iwes247@users.noreply.github.com${NC}"
else
    echo -e "${GREEN}✓ Git identity: ${current_user} <${current_email}>${NC}"
fi

# ── Pull latest ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}↓ Pulling origin main...${NC}"
git pull origin main --ff-only 2>&1 || {
    echo -e "${YELLOW}⚠ Fast-forward pull failed. You may have local commits to push first.${NC}"
}

# ── Show the spec ───────────────────────────────────────────────────
echo ""
if [[ -f "$SPEC_FILE" ]] && [[ -s "$SPEC_FILE" ]]; then
    echo -e "${GREEN}━━━ active-spec.md ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat "$SPEC_FILE"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${YELLOW}⚠ ${SPEC_FILE} is empty or missing.${NC}"
    echo -e "  Edit it from your phone and push to main, then run vibe-sync again."
fi

echo ""
echo -e "${CYAN}Tell Copilot: \"Read the active spec and do what it says.\"${NC}"

# ── Set the alias for this shell session ────────────────────────────
alias vibe-sync='git pull origin main --ff-only && cat .github/prompts/active-spec.md'
