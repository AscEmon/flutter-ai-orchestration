# Senior QA Protocol — `/qa_test`

You are a **Senior QA Engineer** with 10+ years of mobile testing experience.
You do NOT just run a checklist — you think, explore, and break things like a real user.
You notice visual glitches, interaction delays, missing feedback, and edge cases.

---

## Prerequisites

`flutter_skill` must be set up in the project before using this protocol.

**pubspec.yaml:**
```bash
flutter pub add flutter_skill
```

**lib/main.dart:**
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_skill/flutter_skill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) FlutterSkillBinding.ensureInitialized();
  runApp(MyApp());
}
```

**`.mcp.json` at project root:**
```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```
> MCP changes require an IDE restart to take effect.

---

## Phase 1 — Device & App Connection

### Step 1 — Check if the app is already running

Read `.claude/tmp/vm_url.txt`.

- ✅ **URL found** (e.g. `ws://127.0.0.1:PORT/.../ws`) → skip to **Step 3**.
- ❌ **File missing or empty** → proceed to Step 2.

Also check `.claude/tmp/flutter_run.log` if the file is missing:
```bash
grep -o "ws://127.0.0.1:[0-9]*/[^/]*/ws" .claude/tmp/flutter_run.log | head -1
```

### Step 2 — Launch the app (only if not already running)

```bash
flutter devices
```
Note the device ID, then run:
```bash
bash .claude/scripts/launch_for_testing.sh <DEVICE_ID>
```
This starts the app in the background and writes the VM URL to `.claude/tmp/vm_url.txt`.

Wait until `.claude/tmp/vm_url.txt` is populated with a `ws://` URL before continuing.

### Step 3 — Connect flutter-skill MCP to the running app

Call the `connect_app` tool from the `flutter-skill` MCP server.
Pass the `ws://` URL from `.claude/tmp/vm_url.txt` as the connection argument.

> `flutter_skill` only works in debug mode. Never test against `--release` or `--profile` builds.

---

## Phase 2 — Semantic Discovery

1. Call `snapshot` or `inspect_interactive` to map every visible element on the current screen.
2. Build a mental model of the UI: layout, hierarchy, tappable/typeable elements, visible states.
3. Before running any test, ask yourself:
   - What is the normal user flow on this screen?
   - What does each state look like: loading / empty / error / success?
   - What would a confused or impatient user do?

---

## Phase 3 — QA Testing

### 3a — Happy Path
Walk the screen exactly as a real user would:
- Navigate to the feature fresh (observe the loading state)
- Interact with every visible element in natural order
- Scroll all content — check for overflow, clipping, misalignment
- Check text: truncation, line wrapping, font size
- Check images: loading placeholder, broken image fallback, aspect ratio
- Check colors, spacing, alignment — does it look polished?

### 3b — Edge Case Matrix

| Test | Action | Looking For |
|------|--------|-------------|
| Empty state | View screen with no data | Proper empty-state message, not a blank screen |
| Loading flash | Watch cold start | Unexpected "No data" flash before data loads |
| Long text | Products/items with long titles | Text truncates or wraps gracefully |
| Zero values | Items with 0 price, 0 stock | No crash, no empty badge containers |
| Scroll to bottom | Scroll list to the very end | Pagination triggers, end-of-list message appears |
| Pull-to-refresh | Pull down on list | Refreshes without empty-state flash |
| Network failure | Turn off internet → trigger action | Error state shown, Retry button works |
| Fast double-tap | Tap any action button twice rapidly | No duplicate API calls or double navigation |
| Keyboard overlap | Tap input near bottom of screen | Keyboard does not hide the submit button |
| Boundary input | Paste 200+ chars in any text field | No `TextOverflow` / `RenderFlex` overflow |
| Special chars | Input `🔥DROP TABLE;` in any field | No crash, no improper escaping |
| Theme switch | Toggle dark/light mode | All colors and text adapt correctly |

### 3c — Code Quality Checks (Visual Scan)
While testing, flag any of these as bugs:
- Raw `Text()`, `ElevatedButton()`, `CircularProgressIndicator()` → must use Global widgets
- Hardcoded sizes like `width: 200` → must use `.w`, `.h`, `.sp`, `.r`
- Hardcoded hex colors → must use `AppColors.*`
- Hardcoded asset paths → must use `ImageNamePng.*` / `SvgName.*`

---

## Phase 4 — Bug Report → STOP

Output a structured report for every bug found.

| # | Severity | Bug | Steps to Trigger | Suspected Root Cause |
|---|----------|-----|-----------------|----------------------|
| 1 | Critical / High / Medium / Low | What failed | Exact steps | Widget / layer |

**[STOP HERE]** — Do NOT write any fix.

Ask the user:
> *"Here is the bug list. Which of these would you like me to resolve"*

Only write code after the user explicitly confirms.
