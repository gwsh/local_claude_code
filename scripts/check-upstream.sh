#!/usr/bin/env bash
# Check upstream official Claude Code repo for bug fixes
# Usage: bash scripts/check-upstream.sh [time-range]
#        bash scripts/check-upstream.sh "3 days ago"

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ORIGIN_BRANCH="main"
SINCE=${1:-"1 week ago"}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Upstream Bug-Fix Check${NC}"
echo -e "${CYAN}  Repo: anthropics/claude-code${NC}"
echo -e "${CYAN}  Since: ${SINCE}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ---- Fetch ----
echo -e "${YELLOW}[1/4] Fetching upstream...${NC}"
git fetch upstream-code 2>/dev/null && echo "  ✓ upstream-code (anthropics/claude-code)" || echo "  ✗ upstream-code fetch failed"
echo ""

# ---- Bug-fix commits ----
echo -e "${YELLOW}[2/4] Bug-fix commits since '${SINCE}'...${NC}"

BRANCH="upstream-code/${ORIGIN_BRANCH}"

if ! git rev-parse --verify "${BRANCH}" >/dev/null 2>&1; then
  echo -e "  ${RED}✗ Branch '${BRANCH}' not found${NC}"
  exit 1
fi

# Filter fix/bug/revert/security commits
FIXES=$(git log --oneline --no-decorate "${BRANCH}" --since="${SINCE}" --grep="fix\|bug\|revert\|crash\|OOM\|memory\|leak\|security\|vulnerability\|CVE" -i 2>/dev/null || echo "")
FIX_COUNT=$(echo "$FIXES" | grep -c . || echo 0)

if [ "$FIX_COUNT" -gt 0 ] && [ -n "$FIXES" ]; then
  echo -e "  ${GREEN}${FIX_COUNT} bug-fix commit(s):${NC}"
  echo "$FIXES" | head -30 | while read -r line; do
    echo "    ${line}"
  done
  if [ "$FIX_COUNT" -gt 30 ]; then
    echo "    ... and $((FIX_COUNT - 30)) more"
  fi
else
  echo -e "  ${GREEN}No bug-fix commits${NC}"
fi
echo ""

# ---- All recent commits (for context) ----
echo -e "${YELLOW}[3/4] All recent commits (for context)...${NC}"

ALL_COUNT=$(git log --oneline "${BRANCH}" --since="${SINCE}" 2>/dev/null | wc -l)
if [ "$ALL_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}${ALL_COUNT} total commit(s):${NC}"
  git log --oneline --no-decorate "${BRANCH}" --since="${SINCE}" | head -20 | while read -r line; do
    echo "    ${line}"
  done
  if [ "$ALL_COUNT" -gt 20 ]; then
    echo "    ... and $((ALL_COUNT - 20)) more"
  fi
else
  echo -e "  No new commits"
fi
echo ""

# ---- Behind/ahead ----
echo -e "${YELLOW}[4/4] Sync status vs origin/${ORIGIN_BRANCH}...${NC}"

UP_BRANCH="${BRANCH}"
behind=$(git rev-list --count "origin/${ORIGIN_BRANCH}..${UP_BRANCH}" 2>/dev/null || echo "?")
ahead=$(git rev-list --count "${UP_BRANCH}..origin/${ORIGIN_BRANCH}" 2>/dev/null || echo "?")

echo -e "  Behind upstream: ${RED}${behind}${NC} commits"
echo -e "  Ahead of upstream: ${GREEN}${ahead}${NC} commits"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Done.${NC}"
echo -e "${CYAN}  Inspect: git log origin/main..upstream-code/main${NC}"
echo -e "${CYAN}========================================${NC}"
