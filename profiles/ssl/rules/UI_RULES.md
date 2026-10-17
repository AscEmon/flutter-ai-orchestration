# UI Rules — Global Widgets & Responsive Sizing

> **Purpose:** Mandatory UI component and sizing rules for all presentation layer code.

---

## Global Widgets (MANDATORY)

| ❌ DON'T USE | ✅ USE INSTEAD |
|-------------|---------------|
| `Text()` | `GlobalText()` |
| `ElevatedButton()` | `GlobalButton()` |
| `TextFormField()` | `GlobalTextFormField()` |
| `DropdownButton()` | `GlobalDropdown()` |
| `Image.asset()` | `GlobalImageLoader()` |
| `CircularProgressIndicator()` | `GlobalLoader()` |
| `AppBar()` | `GlobalAppBar()` |
| `snackbar` | `ViewUtil.snackbar(context, message)` |

---

## Responsive Sizing (MANDATORY)

All sizing MUST use `flutter_screenutil` extensions:

```dart
// ❌ DON'T
Container(width: 200, height: 100)

// ✅ DO
Container(width: 200.w, height: 100.h)
GlobalText(str: 'Hello', fontSize: 16)
```

**Extensions:**
- `.w` — width scaling
- `.h` — height scaling
- `.sp` — font size scaling
- `.r` — radius scaling

---

## Design System

- Colors defined in `AppColors` enum — never hardcode HEX values
- Assets registered in `k_assets.dart` enum — never hardcode asset paths
- After adding any image or SVG → run `ssl_cli generate k_assets.dart`

---

## Common UI Mistakes

- ❌ Using Flutter widgets directly instead of global widgets
- ❌ Hard-coded sizes without ScreenUtil
- ❌ Hardcoding color HEX values instead of using `AppColors`
- ❌ Not running `ssl_cli generate k_assets.dart` after adding new images or SVGs
