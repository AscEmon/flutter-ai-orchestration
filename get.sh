#!/usr/bin/env bash
# ============================================================
# get.sh — one-line installer for flutter-ai-orchestration
#
# Run inside your Flutter project:
#   curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.4/get.sh | bash
#   curl -fsSL .../v2.2.4/get.sh | AI_ORCH_STATE=bloc bash          # force state management
#   curl -fsSL .../v2.2.4/get.sh | bash -s -- --state=bloc          # same thing (note the -s --)
#   curl -fsSL .../v2.2.4/get.sh | bash -s -- --update              # update to the LATEST release (backs up first)
#
# Environment overrides:
#   AI_ORCH_VERSION   release tag to install            (default: v2.2.4)
#   AI_ORCH_STATE     riverpod | bloc | custom — same as --state (easier with curl | bash)
#   AI_ORCH_PROFILE   ssl | generic — same as --profile
#   AI_ORCH_REPO      GitHub owner/repo                 (default: AscEmon/flutter-ai-orchestration)
#   AI_ORCH_TARBALL   full tarball URL (e.g. an internal GitLab mirror) — overrides the two above
#
# All extra arguments are passed to install.sh (--force, --profile=ssl|generic, --state=riverpod|bloc|custom).
# ============================================================
set -euo pipefail

VERSION="${AI_ORCH_VERSION:-v2.2.4}"

# --update: install the LATEST release tag over an existing install (implies --force)
ARGS=()
UPDATE=0
for a in "$@"; do
    if [ "$a" = "--update" ]; then UPDATE=1; else ARGS+=("$a"); fi
done
if [ "$UPDATE" = 1 ]; then
    if [ -z "${AI_ORCH_VERSION:-}" ]; then
        LATEST=$(git ls-remote --tags --refs "https://github.com/${AI_ORCH_REPO:-AscEmon/flutter-ai-orchestration}.git" 'v*' 2>/dev/null \
                 | sed 's#.*refs/tags/##' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
                 | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | sed 's/^/v/')
        [ -n "$LATEST" ] && VERSION="$LATEST"
    fi
    CURRENT=$(grep '^version=' .claude/ai-orchestration.version 2>/dev/null | cut -d= -f2 || true)
    echo "• Update: ${CURRENT:-not installed} → ${VERSION}"
    if [ -n "$CURRENT" ] && [ "$CURRENT" = "$VERSION" ]; then echo "✔ Already up to date."; exit 0; fi
    ARGS+=("--force")
fi
set -- ${ARGS[@]+"${ARGS[@]}"}
REPO="${AI_ORCH_REPO:-AscEmon/flutter-ai-orchestration}"
TARBALL="${AI_ORCH_TARBALL:-https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz}"

# (install.sh validates the folder: a Flutter project, or an empty folder it can create one in)
command -v curl >/dev/null 2>&1 || { echo "✖ curl is required"; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "✖ tar is required"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "• Downloading flutter-ai-orchestration ${VERSION}"
echo "  from ${TARBALL}"
if ! curl -fsSL "$TARBALL" | tar -xz -C "$TMP" --strip-components=1; then
    echo "✖ Download failed. Check the version tag exists: https://github.com/${REPO}/tags"
    exit 1
fi
[ -f "$TMP/install.sh" ] || { echo "✖ Downloaded archive has no install.sh"; exit 1; }

AI_ORCH_VERSION="$VERSION" bash "$TMP/install.sh" "$PWD" "$@"
echo "• Installed version: ${VERSION}"
