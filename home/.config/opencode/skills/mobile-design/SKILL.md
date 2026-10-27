---
name: mobile-design
description: Dual-mode mobile/tablet design skill. NEW projects get fresh modern design. EXISTING projects extract and follow the project's design system. Outputs real code (Flutter/SwiftUI/Compose), not mockups.
---

# Mobile Design Skill for Claude Code

## Dual-Mode Logic

Before ANY design work, run detection:

### Step 1: Project Detection

Scan the project root for design signals:

```
FIND:
- Theme files: theme.dart, colors.dart, app_theme.dart, DesignSystem.swift, Colors.xcassets, Theme.kt
- Style configs: typography.dart, fonts.dart, spacing.dart, styles.xml
- Design tokens: *.tokens.json, design-tokens.*, figma-tokens.json
- Component library: components/, widgets/, design_system/, ui_kit/
- Asset catalogs: assets/images/, Assets.xcassets/, res/drawable/
- Config: pubspec.yaml (Flutter), Package.swift (iOS), build.gradle (Android/KMP)
- Existing screens: screens/, views/, features/, presentation/
```

### Step 2: Mode Selection

```
IF found ≥3 design signals (theme + colors + typography/components):
  → MODE: EXISTING (follow project design)

IF found <3 design signals OR empty/new project:
  → MODE: FRESH (create new design system)
```

---

## MODE: EXISTING — Follow Project Design

When the project already has a design system:

### Extract Rules

1. **Colors**: Read the project's color definitions. Use EXACT same hex values. Never invent new colors.
   - Flutter: `Color(0xFF...)`, `MaterialColor`, color constants
   - SwiftUI: `Color("name")`, asset catalog colors
   - Compose: `Color(0xFF...)`, `colorResource()`

2. **Typography**: Match font family, weight, size scale exactly.
   - Extract `TextStyle`, `Font`, `Typography` definitions
   - Match the project's type scale ratio

3. **Spacing**: Follow the project's spacing system (4dp/8dp grid, etc.)
   - Find padding/margin conventions
   - Reuse spacing constants

4. **Components**: Use existing widgets/components FIRST.
   - Check `widgets/`, `components/`, `shared/` folders
   - Reuse existing Button, Card, Input, AppBar variants
   - Only create new components when genuinely needed

5. **Patterns**: Follow existing architectural patterns.
   - Same state management approach (GetX/Riverpod/BLoC/Provider)
   - Same navigation pattern
   - Same folder structure

### Output Rules for EXISTING Mode

- Import from existing theme/color/typography files — NEVER hardcode new values
- Extend existing widget library — don't duplicate
- Match existing code style (const constructors, naming conventions)
- If adding new colors: add to the EXISTING theme file, not inline

---

## MODE: FRESH — New Design System

When the project is new or has no design system:

### Step 1: Choose Design Direction

Ask the user OR auto-select based on project type:

| Project Type | Recommended Style |
|---|---|
| Social / Chat | Glassmorphism + vibrant gradients |
| Finance / Banking | Clean minimal + trust blues + subtle shadows |
| E-commerce | Bold colors + card-heavy + action-oriented |
| Health / Fitness | Organic shapes + green/teal + rounded corners |
| Productivity | Minimal monochrome + accent color + tight spacing |
| Crypto / Web3 | Dark mode + neon accents + futuristic |
| Education | Friendly rounded + warm colors + playful icons |
| Food / Delivery | Appetizing warm tones + large imagery + bold CTAs |

### Step 2: Create Design System Files

Generate a complete, cohesive design system:

**Color Palette** (always generate):
```
Primary:     1 main brand color
Secondary:   1 complement
Surface:     background, card, elevated
On-Surface:  text primary, text secondary, text disabled
Status:      success, warning, error, info
Accent:      1 highlight/CTA color
```

**Typography Scale** (always generate):
```
Display:  32-40sp bold (hero text)
Headline: 24-28sp semi-bold (section headers)
Title:    18-22sp medium (card titles, list headers)
Body:     14-16sp regular (main content)
Caption:  11-12sp regular (labels, hints)
```

**Spacing System**:
```
Unit: 4dp base
Scale: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

**Shape System**:
```
Small:   8dp radius (chips, badges)
Medium:  12dp radius (cards, inputs)
Large:   16dp radius (modals, bottom sheets)
Full:    50% (avatar, FAB)
```

### Step 3: Mobile + Tablet Responsive

All designs MUST support:

**Phone (compact)**:
- 360-430dp width
- Single column layouts
- Bottom navigation
- Collapsible headers/app bars

**Tablet (medium/expanded)**:
- 600-900dp width
- Multi-column layouts (sidebar + content)
- Navigation rail or side navigation
- Split-view for master-detail flows
- Adapted spacing (wider margins, larger cards)

**Breakpoints** (Flutter):
```dart
compact:  width < 600
medium:   600 ≤ width < 840
expanded: width ≥ 840
```

**Breakpoints** (SwiftUI):
```swift
compact:   horizontalSizeClass == .compact
regular:   horizontalSizeClass == .regular
```

### Step 4: Generate Base Components

Create these core components for the design system:

1. **AppButton** — primary, secondary, outline, ghost, danger variants
2. **AppCard** — with elevation, border, filled variants
3. **AppTextField** — with label, hint, error, icon support
4. **AppBar** — adaptive (phone: bottom bar, tablet: rail)
5. **AppNavigation** — responsive navigation scaffold
6. **AppAvatar** — with placeholder, status indicator
7. **AppChip** / **AppBadge** — for tags and notifications
8. **AppLoading** — shimmer skeleton + spinner variants
9. **AppEmpty** — empty state illustrations
10. **AppModal** — bottom sheet (phone) / dialog (tablet)

---

## Design Quality Checklist

Every design output must pass:

- [ ] Colors have sufficient contrast (WCAG AA minimum: 4.5:1 text, 3:1 large text)
- [ ] Touch targets ≥ 48dp
- [ ] No hardcoded strings — use localization keys
- [ ] No magic numbers — use spacing/sizing constants
- [ ] Dark mode supported (or explicitly scoped to light)
- [ ] Tablet layout tested (not just phone stretched wide)
- [ ] Consistent with chosen style direction
- [ ] Animations/transitions specified where appropriate
- [ ] Loading, error, empty states designed — not just happy path
- [ ] Safe area / notch / status bar accounted for
- [ ] Accessibility: semantic labels, screen reader order, focus management

---

## Tech Stack Templates

### Flutter
```
lib/
  core/
    theme/
      app_colors.dart
      app_typography.dart
      app_spacing.dart
      app_theme.dart
    widgets/
      app_button.dart
      app_card.dart
      app_text_field.dart
      app_scaffold.dart
  features/
    [feature]/
      presentation/
        screens/
        widgets/
```

### SwiftUI
```
[Project]/
  DesignSystem/
    Colors.swift
    Typography.swift
    Spacing.swift
    Components/
      AppButton.swift
      AppCard.swift
      AppTextField.swift
  Features/
    [Feature]/
      Views/
      Components/
```

### Compose Multiplatform
```
shared/
  designsystem/
    Color.kt
    Type.kt
    Shape.kt
    Spacing.kt
    components/
      AppButton.kt
      AppCard.kt
      AppTextField.kt
  features/
    [feature]/
      ui/
        screens/
        components/
```

---

## Invocation Rules

1. Always detect mode (EXISTING vs FRESH) before generating code
2. Announce the detected mode to user: `"🎨 Mode: EXISTING — following project design"` or `"🎨 Mode: FRESH — creating new design system"`
3. In EXISTING mode: show which design tokens were extracted before building
4. In FRESH mode: propose color palette + typography first, get confirmation, then build
5. Always generate responsive layouts (phone + tablet), not phone-only
6. Never output design without the quality checklist
