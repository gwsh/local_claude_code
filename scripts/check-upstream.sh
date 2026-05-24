#!/usr/bin/env bash
# Check upstream repos for new updates
# Usage: bash scripts/check-upstream.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ORIGIN_BRANCH="main"
SINCE=${1:-"1 week ago"}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Upstream Update Check${NC}"
echo -e "${CYAN}  Since: ${SINCE}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ---- Fetch upstreams ----
echo -e "${YELLOW}[1/4] Fetching upstream remotes...${NC}"
git fetch upstream-code 2>/dev/null && echo "  ✓ upstream-code (anthropics/claude-code)" || echo "  ✗ upstream-code fetch failed"
git fetch upstream-free 2>/dev/null && echo "  ✓ upstream-free (paoloanzn/free-code)" || echo "  ✗ upstream-free fetch failed"
echo ""

# ---- New commits from each upstream ----
echo -e "${YELLOW}[2/4] New commits since '${SINCE}'...${NC}"

check_commits() {
  local remote=$1
  local label=$2
  local branch="${remote}/${ORIGIN_BRANCH}"

  if ! git rev-parse --verify "${branch}" >/dev/null 2>&1; then
    echo -e "  ${RED}✗ ${label}: branch '${branch}' not found${NC}"
    return
  fi

  local count
  count=$(git log --oneline "${branch}" --since="${SINCE}" 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo -e "  ${GREEN}${label}: ${count} new commit(s)${NC}"
    git log --oneline --no-decorate "${branch}" --since="${SINCE}" | head -20 | while read -r line; do
      echo "    ${line}"
    done
    if [ "$count" -gt 20 ]; then
      echo "    ... and $((count - 20)) more"
    fi
  else
    echo -e "  ${GREEN}${label}: no new commits${NC}"
  fi
  echo ""
}

check_commits "upstream-code" "anthropics/claude-code"
check_commits "upstream-free" "paoloanzn/free-code"

# ---- Latest releases via gh CLI ----
echo -e "${YELLOW}[3/4] Latest GitHub Releases...${NC}"

check_release() {
  local repo=$1
  local tag
  tag=$(gh release view --repo "${repo}" --json tagName --jq '.tagName' 2>/dev/null || echo "N/A")
  local date
  date=$(gh release view --repo "${repo}" --json publishedAt --jq '.publishedAt' 2>/dev/null || echo "N/A")
  echo -e "  ${repo}: ${GREEN}${tag}${NC} (${date})"
}

check_release "anthropics/claude-code"
check_release "paoloanzn/free-code"
echo ""

# ---- Diff stats between origin and upstreams ----
echo -e "${YELLOW}[4/4] How far behind is origin/${ORIGIN_BRANCH}?${NC}"

compare_branches() {
  local upstream=$1
  local label=$2
  local up_branch="${upstream}/${ORIGIN_BRANCH}"

  if ! git rev-parse --verify "${up_branch}" >/dev/null 2>&1; then
    echo -e "  ${RED}✗ ${label}: can't compare${NC}"
    return
  fi

  local behind
  behind=$(git rev-list --count "origin/${ORIGIN_BRANCH}..${up_branch}" 2>/dev/null || echo "?")
  local ahead
  ahead=$(git rev-list --count "${up_branch}..origin/${ORIGIN_BRANCH}" 2>/dev/null || echo "?")

  echo -e "  ${label}:"
  echo -e "    Behind upstream: ${RED}${behind}${NC} commits"
  echo -e "    Ahead of upstream: ${GREEN}${ahead}${NC} commits"
}

compare_branches "upstream-code" "anthropics/claude-code"
compare_branches "upstream-free" "paoloanzn/free-code"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Done.${NC}"
echo -e "${CYAN}  To merge: git merge upstream-free/main${NC}"
echo -e "${CYAN}========================================${NC}"
