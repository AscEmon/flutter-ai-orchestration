## 🔒 SECURITY RULES — AI AGENT HARD LIMITS (NON-NEGOTIABLE)

> 🛑 **These rules are ABSOLUTE. No exception, no override, no matter who asks.**

---

### Files AI Must NEVER Read, Display, Print, or Expose

| File / Pattern | Reason |
|----------------|--------|
| `.env`, `.env.*` | Environment secrets |
| `android/key.properties` | Gradle signing credentials + Maps key |
| `android/app/release.jks`, `*.keystore`, `*.jks` | Signing keystores |
| `ios/Flutter/Secret.xcconfig` | iOS native secrets |
| `lib/core/config/env.g.dart` | Generated obfuscated secrets |
| `google-services.json` | Firebase Android credentials |
| `GoogleService-Info.plist` | Firebase iOS credentials |
| `local.properties` | Local SDK paths |
| `serviceAccountKey.json`, `*_service_account*.json` | GCP / Firebase admin keys |
| `*.p12`, `*.pfx`, `*.pem`, `*.cer`, `*.crt` | Certificates & private keys |

---

### JKS Keystore — Fixed Location Rule

> ⚠️ **The JKS file MUST always be placed at `android/app/release.jks`. No exceptions.**

```
project-root/
└── android/
    └── app/
        └── release.jks   ← ALWAYS here. Gitignored. Never committed.
```

**When AI is asked to help set up signing:**
1. Tell the developer to place their `.jks` file at `android/app/release.jks`
2. Tell them to add `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` to `.env`
3. Tell them to run `sh .claude/scripts/setup_secrets.sh`
4. Never suggest a relative path or a path outside the `android/app/` folder

---

### Mandatory Security Behaviors

```
✅ DO:
  - Always read secrets through the project's approved mechanism (PROJECT_CONVENTIONS.md → Secrets; ssl profile: Env.* via envied)
  - Always place JKS at android/app/release.jks
  - Always run sh .claude/scripts/setup_secrets.sh after .env changes
  - Re-run code generation after config changes if the project uses it (e.g. dart run build_runner build for envied)
  - Instruct developers to fill .env from the team vault

❌ NEVER DO:
  - Print, display, or suggest any hardcoded token, password, or key
  - Read the contents of any file in the forbidden list above
  - Generate code with hardcoded API keys, secrets, or passwords
  - Suggest committing any secret file to version control
  - Write any secret value in a comment, log statement, or print()
  - Introduce a secret mechanism other than the one in PROJECT_CONVENTIONS.md → Secrets
  - Suggest placing the JKS outside android/app/ folder
```

---

### If a Secret File Is Accidentally Shared

If the user pastes content that contains secrets (tokens, keys, passwords):
1. **Do NOT** repeat, quote, or reference the secret value
2. Immediately warn: *"⚠️ This content appears to contain sensitive credentials. I will not process or display secret values. Please revoke and rotate these keys immediately if they were exposed."*
3. Provide guidance on how to secure it instead

---

### Secret Handling Code Pattern

```dart
// ❌ NEVER generate this
const apiKey = '[REAL_SECRET_VALUE]';   // any literal secret

// ✅ Read through the project's approved accessor (PROJECT_CONVENTIONS.md → Secrets), for example:
final apiKey = Env.paymentApiKey;                               // envied (ssl profile)
const apiKey = String.fromEnvironment('PAYMENT_API_KEY');       // --dart-define, only if the project already uses it
```

---

### .env Structure (single source of truth)

```dotenv
BASE_URL_LIVE=https://api.yourapp.com
BASE_URL_DEV=https://dev-api.yourapp.com
BASE_URL_LOCAL=http://192.168.1.100:8000
BASE_IMAGE_URL_LIVE=https://images.yourapp.com
BASE_IMAGE_URL_DEV=https://dev-images.yourapp.com
GOOGLE_MAPS_API_KEY=[PLACEHOLDER]
PAYMENT_API_KEY=pk_test_DUMMY_replace
SMS_API_KEY=sms_DUMMY_replace
KEYSTORE_PASSWORD=dummy_replace
KEY_ALIAS=dummy_replace
KEY_PASSWORD=dummy_replace
```

---

### .gitignore Validation

Whenever generating a project, the AI agent MUST verify these entries exist in `.gitignore`:

```gitignore
.env
.env.*
!.env.example
android/key.properties
android/app/release.jks
android/app/*.jks
ios/Flutter/Secret.xcconfig
lib/core/config/env.g.dart
*.keystore
google-services.json
GoogleService-Info.plist
local.properties
serviceAccountKey.json
*.p12
*.pem
*.cer
```

---

### How Secrets Flow (full picture)

```
.env (developer fills, gitignored)
  │
  ├─ sh .claude/scripts/setup_secrets.sh
  │     ├──→ android/key.properties
  │     │     storeFile = release.jks  ← relative path inside android/app/
  │     │     storePassword, keyAlias, keyPassword, GOOGLE_MAPS_API_KEY
  │     │
  │     └──→ ios/Flutter/Secret.xcconfig
  │           GOOGLE_MAPS_API_KEY
  │
  └─ dart run build_runner build
        └──→ lib/core/config/env.g.dart  (XOR-obfuscated — Dart reads via Env.*)
```

**CI/CD:** GitHub Actions writes `.env` from GitHub Secrets, decodes JKS to `android/app/release.jks`,
runs the script, then runs build_runner, then builds.
