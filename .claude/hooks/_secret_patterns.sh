#!/bin/bash
# ============================================================
# _secret_patterns.sh  —  Shared detection library
# Sourced by all other hook scripts. Do NOT run directly.
# ============================================================

# ── 1. Protected filenames (never commit these) ────────────
BLOCKED_FILES=(
    ".env"
    ".env.local"
    ".env.production"
    ".env.staging"
    ".env.development"
    "key.properties"
    "local.properties"
    "keystore.jks"
    "release.jks"
    "release.keystore"
    "debug.keystore"
    "GoogleService-Info.plist"
    "google-services.json"
    "firebase_options.dart"
    "secrets.dart"
    "api_keys.dart"
    "credentials.dart"
    ".netrc"
    "service-account.json"
    "service_account.json"
)

# ── 2. Secret patterns (LABEL:::REGEX) ────────────────────
SECRET_PATTERNS=(
    "Google API Key:::AIza[0-9A-Za-z\-_]{35}"
    "Google OAuth Client ID:::[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com"
    "Firebase URL:::https://[a-z0-9-]+\.firebaseio\.com"
    "Generic api_key:::api[_-]?key\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]"
    "Generic apiKey:::apiKey\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]"
    "Generic secret:::secret\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]"
    "Generic token:::token\s*[:=]\s*['\"][A-Za-z0-9_\-]{20,}['\"]"
    "Generic password:::password\s*=\s*['\"][^'\"]{6,}['\"]"
    "AWS Access Key:::AKIA[0-9A-Z]{16}"
    "AWS Secret Key:::aws_secret_access_key\s*=\s*[A-Za-z0-9/+]{40}"
    "Stripe Secret Key:::sk_live_[0-9a-zA-Z]{24}"
    "Stripe Test Key:::sk_test_[0-9a-zA-Z]{24}"
    "GitHub Token:::ghp_[A-Za-z0-9]{36}"
    "Slack Token:::xox[baprs]-[0-9A-Za-z\-]{10,48}"
    "Bearer Token:::Bearer\s+[A-Za-z0-9\-._~+/]{20,}"
)

# ── Check filename against blocked list ────────────────────
is_blocked_filename() {
    local filepath="$1"
    local bname
    bname=$(basename "$filepath")
    for pattern in "${BLOCKED_FILES[@]}"; do
        if [[ "$bname" == "$pattern" ]] || [[ "$filepath" == *"/$pattern" ]]; then
            echo "$pattern"; return 0
        fi
    done
    return 1
}

# ── Scan file content for secret patterns ──────────────────
scan_file_for_secrets() {
    local filepath="$1"
    local found=0
    for entry in "${SECRET_PATTERNS[@]}"; do
        local label="${entry%%%:::*}"
        local pattern="${entry#*:::}"
        if grep -qPi "$pattern" "$filepath" 2>/dev/null; then
            local linenum
            linenum=$(grep -nPi "$pattern" "$filepath" 2>/dev/null | head -1 | cut -d: -f1)
            echo "    [SECRET] $label  →  line $linenum in $filepath"
            found=1
        fi
    done
    return $found
}

# ── Scan git diff patch for secret patterns ────────────────
scan_patch_for_secrets() {
    local patch="$1"
    local label="$2"
    local found=0
    for entry in "${SECRET_PATTERNS[@]}"; do
        local slabel="${entry%%%:::*}"
        local pattern="${entry#*:::}"
        if echo "$patch" | grep -P "^\+" | grep -qPi "$pattern" 2>/dev/null; then
            echo "    [SECRET] $slabel  →  in staged changes of $label"
            found=1
        fi
    done
    return $found
}
