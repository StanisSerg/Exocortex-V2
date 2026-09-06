#!/bin/bash
# routing: helper  skill=week-close,day-close  called-by=haiku
# see DP.SC.159, DP.ROLE.059
# check-dirty-repos.sh — Скан всех IWE репо на незакоммиченные изменения
# Использование: ./scripts/check-dirty-repos.sh
# Вызывается из Day Close для обнаружения "забытых" файлов.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../.claude/lib/iwe-env-bootstrap.sh" || exit 1
IWE_DIR="$WORKSPACE_DIR"
DIRTY=0
UNPUSHED=0

check_repo() {
    local dir="$1"
    local name="$2"

    if [ ! -e "$dir/.git" ]; then return; fi

    cd "$dir"

    # Uncommitted changes
    local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ]; then
        echo "⚠️  $name: $changes незакоммиченных файлов"
        git status --porcelain 2>/dev/null | head -5
        [ "$changes" -gt 5 ] && echo "   ... и ещё $((changes - 5))"
        DIRTY=$((DIRTY + 1))
    fi

    # Unpushed commits (только репо пилота; чужой upstream без push-прав — норма, не шумим)
    local ahead=$(git rev-list --count HEAD...@{upstream} --left-only 2>/dev/null || echo "0")
    if [ "$ahead" -gt 0 ]; then
        local url=$(git remote get-url origin 2>/dev/null || echo "")
        local owner=$(echo "$url" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#')
        if [ -n "$PILOT_OWNER" ] && [ -n "$owner" ] && [ "$owner" != "$PILOT_OWNER" ]; then
            echo "ℹ️  $name: $ahead локальных коммитов (upstream $owner, push невозможен — норма)"
        else
            echo "↗️  $name: $ahead незапушенных коммитов"
            UNPUSHED=$((UNPUSHED + 1))
        fi
    fi
}

echo "🔍 Скан IWE репозиториев..."
echo ""

# Владелец workspace = владелец governance-репо (для отличия своих репо от чужого upstream)
PILOT_OWNER=$(git -C "$IWE_DIR/${IWE_GOVERNANCE_REPO:-DS-strategy}" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#' || echo "")

# Workspace root itself is a repo too (submodule pointers)
[ -e "$IWE_DIR/.git" ] && check_repo "$IWE_DIR" "IWE (root)"

# Top-level repos
for dir in "$IWE_DIR"/*/; do
    [ -e "$dir/.git" ] && check_repo "$dir" "$(basename "$dir")"
done

# Nested repos (two levels deep)
for dir in "$IWE_DIR"/*/*/; do
    [ -e "$dir/.git" ] && check_repo "$dir" "$(basename "$(dirname "$dir")")/$(basename "$dir")"
done

echo ""
if [ "$DIRTY" -eq 0 ] && [ "$UNPUSHED" -eq 0 ]; then
    echo "✅ Все репо чистые и запушены"
else
    [ "$DIRTY" -gt 0 ] && echo "⚠️  $DIRTY репо с незакоммиченными изменениями"
    [ "$UNPUSHED" -gt 0 ] && echo "↗️  $UNPUSHED репо с незапушенными коммитами"
fi
