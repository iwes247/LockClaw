#!/usr/bin/env bash
# vibe-sync.sh — Phone-to-VS Code bridge for LockClaw
# Run this after pushing active-spec.md from your phone.
#
# Usage:
#   ./scripts/vibe-sync.sh          # from any LockClaw repo root
#   source ./scripts/vibe-sync.sh   # same, but stays in shell
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. Identity guard
EXPECTED_USER="iwes247"
CURRENT_USER=$(git config user.name 2>/dev/null || echo "UNSET")

if [ "$CURRENT_USER" != "$EXPECTED_USER" ]; then
    echo -e "${YELLOW}⚠ Git identity is '$CURRENT_USER', expected '$EXPECTED_USER'${NC}"
    echo -e "${YELLOW}  Fixing...${NC}"
    git config user.name "$EXPECTED_USER"
    git config user.email "${EXPECTED_USER}@users.noreply.github.com"
    echo -e "${GREEN}✅ Identity set to $EXPECTED_USER${NC}"
fi

# 2. Pull latest from remote
echo -e "${CYAN}⬇ Pulling latest...${NC}"
git pull origin main --ff-only

# 3. Show the active spec if it exists
SPEC=".github/prompts/active-spec.md"
if [ -f "$SPEC" ]; then
    echo ""
    echo -e "${GREEN}━━━ Active Spec ━━━${NC}"
    cat "$SPEC"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}⚠ No $SPEC found in this repo.${NC}"
fi
