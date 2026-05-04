#!/bin/bash
# .claude/scripts/setup_secrets.sh
#
# PURPOSE:
#   Reads .env and:
#     1. Decodes RELEASE_JKS_BASE64          → android/app/release.jks
#     2. Decodes GOOGLE_SERVICES_JSON_BASE64  → android/app/google-services.json
#     3. Decodes GOOGLE_SERVICE_INFO_BASE64   → ios/Runner/GoogleService-Info.plist
#     4. Generates android/key.properties     (Gradle signing + Maps key)
#     5. Generates ios/Flutter/Secret.xcconfig (Xcode Maps key)
#
# HOW TO RUN (always from project root):
#   sh .claude/scripts/setup_secrets.sh
#
# RE-RUN whenever .env changes.
# All generated / decoded files are gitignored — never commit them.

set -e

# ── Resolve project root ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="$PROJECT_ROOT/.env"
KEY_PROPS="$PROJECT_ROOT/android/key.properties"
XCCONFIG_FILE="$PROJECT_ROOT/ios/Flutter/Secret.xcconfig"
JKS_PATH="$PROJECT_ROOT/android/app/release.jks"
GOOGLE_SERVICES_PATH="$PROJECT_ROOT/android/app/google-services.json"
GOOGLE_SERVICE_INFO_PATH="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"

echo "📂 Project root : $PROJECT_ROOT"
echo ""

# ── Check .env exists ─────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo "❌  .env not found."
    echo "    Run:  cp .env.example .env"
    echo "    Then fill in real values from the team vault."
    exit 1
fi

# ── Helper: read a key from .env ─────────────────────────────────
get_env() {
    local key="$1"
    grep -E "^${key}[[:space:]]*=" "$ENV_FILE" \
        | head -n 1 \
        | sed "s/^${key}[[:space:]]*=[[:space:]]*//" \
        | tr -d '\r' \
        | sed "s/^['\"]//; s/['\"]$//"
}

# ── Helper: decode base64 value to file ──────────────────────────
decode_to_file() {
    local value="$1"
    local output="$2"
    local label="$3"
    # Skip placeholders
    if [ -z "$value" ] || echo "$value" | grep -q "^<"; then
        echo "⏭️   $label — placeholder in .env, skipping"
        return
    fi
    mkdir -p "$(dirname "$output")"
    printf '%s' "$value" | base64 -d > "$output"
    echo "✅  $label decoded → $(basename "$output")"
}

# ── Read values from .env ─────────────────────────────────────────
KEYSTORE_PASSWORD=$(get_env "KEYSTORE_PASSWORD")
KEY_ALIAS=$(get_env "KEY_ALIAS")
KEY_PASSWORD=$(get_env "KEY_PASSWORD")
GOOGLE_MAPS_API_KEY=$(get_env "GOOGLE_MAPS_API_KEY")
RELEASE_JKS_BASE64=$(get_env "RELEASE_JKS_BASE64")
GOOGLE_SERVICES_JSON_BASE64=$(get_env "GOOGLE_SERVICES_JSON_BASE64")
GOOGLE_SERVICE_INFO_BASE64=$(get_env "GOOGLE_SERVICE_INFO_BASE64")

# ── Decode binary files from base64 ──────────────────────────────
echo "── Decoding binary files ────────────────────────────────────"
decode_to_file "$RELEASE_JKS_BASE64"         "$JKS_PATH"                  "release.jks"
decode_to_file "$GOOGLE_SERVICES_JSON_BASE64" "$GOOGLE_SERVICES_PATH"     "google-services.json"
decode_to_file "$GOOGLE_SERVICE_INFO_BASE64"  "$GOOGLE_SERVICE_INFO_PATH" "GoogleService-Info.plist"
echo ""

# ── Warn if JKS still missing ─────────────────────────────────────
if [ ! -f "$JKS_PATH" ]; then
    echo "⚠️  release.jks not found — add RELEASE_JKS_BASE64 to .env"
    echo "   Debug builds still work. Release builds will fail."
    echo ""
fi

# ── Validate signing fields ───────────────────────────────────────
HAS_WARNING=false
check_field() {
    local name="$1"
    local value="$2"
    if [ -z "$value" ]; then
        echo "⚠️   $name is empty in .env"
        HAS_WARNING=true
    fi
}
check_field "KEYSTORE_PASSWORD"   "$KEYSTORE_PASSWORD"
check_field "KEY_ALIAS"           "$KEY_ALIAS"
check_field "KEY_PASSWORD"        "$KEY_PASSWORD"
check_field "GOOGLE_MAPS_API_KEY" "$GOOGLE_MAPS_API_KEY"

if [ "$HAS_WARNING" = true ]; then
    echo ""
    echo "   Fill the missing values in .env and re-run this script."
    echo ""
fi

# ── Generate android/key.properties ──────────────────────────────
echo "── Generating native config files ───────────────────────────"
mkdir -p "$(dirname "$KEY_PROPS")"
{
    echo "# Auto-generated — DO NOT edit. Edit .env and re-run script."
    echo ""
    echo "storeFile=release.jks"
    echo "storePassword=$KEYSTORE_PASSWORD"
    echo "keyAlias=$KEY_ALIAS"
    echo "keyPassword=$KEY_PASSWORD"
    echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY"
} > "$KEY_PROPS"
echo "✅  android/key.properties generated"

# ── Generate ios/Flutter/Secret.xcconfig ─────────────────────────
mkdir -p "$(dirname "$XCCONFIG_FILE")"
{
    echo "// Auto-generated — DO NOT edit. Edit .env and re-run script."
    echo ""
    echo "GOOGLE_MAPS_API_KEY = $GOOGLE_MAPS_API_KEY"
} > "$XCCONFIG_FILE"
echo "✅  ios/Flutter/Secret.xcconfig generated"

echo ""
echo "✅  All done. Next step:"
echo "    dart run build_runner build --delete-conflicting-outputs"
