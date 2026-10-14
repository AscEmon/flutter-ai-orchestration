#!/usr/bin/env bash
# ============================================================
# get.sh — one-line installer for flutter-ai-orchestration
#
# Run inside your Flutter project:
#   curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.0/get.sh | bash
#   curl -fsSL .../v2.0.0/get.sh | bash -s -- --state=bloc          # force state management
#   curl -fsSL .../v2.1.0/get.sh | bash -s -- --force               # upgrade (backs up first)
#
# Environment overrides:
#   AI_ORCH_VERSION   release tag to install            (default: v2.0.0)
#   AI_ORCH_REPO      GitHub owner/repo                 (default: AscEmon/flutter-ai-orchestration)
#   AI_ORCH_TARBALL   full tarball URL (e.g. an internal GitLab mirror) — overrides the two above
#
# All extra arguments are passed to install.sh (--force, --state=riverpod|bloc).
# ============================================================
set -euo pipefail

VERSION="${AI_ORCH_VERSION:-v2.0.0}"
REPO="${AI_ORCH_REPO:-AscEmon/flutter-ai-orchestration}"
TARBALL="${AI_ORCH_TARBALL:-https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz}"

[ -f pubspec.yaml ] || { echo "✖ Run this inside a Flutter project (no pubspec.yaml in $PWD)"; exit 1; }
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

bash "$TMP/install.sh" "$PWD" "$@"
echo "• Installed version: ${VERSION}"
