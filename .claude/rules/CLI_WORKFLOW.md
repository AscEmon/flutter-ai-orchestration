# CLI Workflow — ssl_cli & autosafe_json

> **Purpose:** Step-by-step workflow AI agents MUST follow before writing any code.

## ⚠️ **Before handling any secret, key, or credential — read `.claude/docs/SECURITY.md` first. Those rules are ABSOLUTE.**

## Step 1 — Check if ssl_cli is Installed

```bash
ssl_cli help --all
```

- ✅ **If output is shown** → ssl_cli is installed. Proceed to Step 2.
- ❌ **If command not found** → Install it first:

```bash
dart pub global activate ssl_cli
```

Then verify PATH is set:
- **macOS/Linux:** `export PATH="$PATH":"$HOME/.pub-cache/bin"` → add to `~/.zshrc` or `~/.bashrc`
- **Windows:** Add Dart pub cache to System Environment Variables

---

## Step 2 — Use ssl_cli for ALL Scaffolding

> 🚫 **AI agents MUST NOT manually create folders/files for project or module scaffolding.**
> ✅ **ALWAYS use ssl_cli commands. This saves tokens and ensures consistent structure.**

### Creating a New Project

```bash
ssl_cli create <project_name>
```
- When prompted for pattern → **select pattern `4`** (Clean Architecture)
- When prompted for state management → **select `Riverpod`**

### Adding a New Feature Module

```bash
ssl_cli module <module_name>
```
- When prompted for pattern → **select Clean Architecture pattern `3`**
- When prompted for state management → **select `Riverpod`**

### After Adding Assets (Images / SVGs)

> ⚠️ **Whenever any image or SVG file is added to the assets folder, run this immediately:**

```bash
ssl_cli generate k_assets.dart
```

**Rules:**
- ✅ ALWAYS run after adding any `.png`, `.jpg`, `.jpeg`, `.svg` file
- ✅ Reference assets via generated enum only (e.g. `ImageNamePng.myImage`, `SvgName.myIcon`)
- ❌ NEVER hardcode asset paths as raw strings

### Build & Release

```bash
ssl_cli build apk --flavorType       # --DEV / --LIVE / --LOCAL / --STAGE
ssl_cli build apk --flavorType --t   # Build + auto-share to Telegram
```

---

## Step 3 — Check autosafe_json

```bash
autosafe --version
```

- ❌ **If command not found** → Install:

```bash
dart pub global activate autosafe_json
```

- Add to `pubspec.yaml`:
```yaml
dependencies:
  autosafe_json: ^1.0.0
```

### After Every Model Change

```bash
autosafe /path/to/your/model/{model_name}_model.dart
```

---

## Step 4 — Fill in Logic

Once ssl_cli generates the structure, fill in:
- Entity fields
- Model `fromJson` / `toJson`
- UseCase business logic
- Repository implementation
- Provider state & actions
- UI page & widgets

> Only write code **inside** the generated files. Never create new folders manually.

---

## Agent Decision Flow

```
AI receives a task
       ↓
Run: ssl_cli help --all
       ↓
Found? ──No──→ dart pub global activate ssl_cli → verify → continue
       │
      Yes
       ↓
Is autosafe_json activated?
       ↓
Run: autosafe --version
       ↓
Found? ──No──→ dart pub global activate autosafe_json → verify → continue
       │
      Yes
       ↓
Is it a new project? ──Yes──→ ssl_cli create <project_name> (pick pattern 4 + Riverpod)
       │                       + Verify .gitignore has all secret file entries
      No
       ↓
Is it a new feature? ──Yes──→ ssl_cli module <module_name> (pick pattern 3 + Riverpod)
       │
      No
       ↓
Did you write or modify a fromJson? ──Yes──→ autosafe /path/to/model.dart
       │
      No
       ↓
Added new assets? ──Yes──→ ssl_cli generate k_assets.dart
       │
      No
       ↓
Fill in logic inside generated files following architecture rules
```
