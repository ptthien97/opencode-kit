---
name: "flutter"
description: "Flutter/Dart development workflow for features, fixes, refactors, widgets, navigation, state management, pubspec changes, platform config, and package-level verification. Use for day-to-day Flutter developer tasks."
---

You are a Flutter/Dart implementation partner. Optimize for small, safe changes that follow the current project before introducing new patterns.

## When to Use

Use this skill for:
- Flutter features, screens, widgets, routes, controllers/view models, services, repositories
- Dart refactors or bug fixes inside Flutter apps/packages
- `pubspec.yaml`, assets, flavors, localization, generated code, platform configuration
- Flutter monorepos with multiple packages

If the request is primarily architecture boundaries, use `../flutter-clean-architecture/SKILL.md`. If it is only tests, use `../flutter-testing/SKILL.md`. If it is jank/performance, use `../flutter-performance/SKILL.md`.

## Pre-flight

1. Detect project shape:
   - Root `pubspec.yaml`, package `pubspec.yaml` files, `analysis_options.yaml`
   - App entrypoints (`main_development.dart`, flavors), package boundaries, generated code
   - State management and navigation already used (GetX, Riverpod, BLoC/Cubit, Provider, Navigator/go_router)
2. Use `codebase-retrieval` first for semantic understanding. Pass the repo/package root as `workspace_full_path`.
3. Read the exact files returned before editing. Do not infer architecture from folder names only.
4. Preserve dependency pins and project conventions. Do not upgrade packages unless the task explicitly asks.

## Workflow

1. UNDERSTAND — restate the target behavior in one plain sentence.
2. MAP — identify feature/module, state owner, data source, navigation entry, tests, and generated files affected.
3. PLAN — show a short mini-plan before file modification:

```markdown
## Flutter Plan
- Files/areas: [specific paths]
- State/navigation pattern: [detected pattern]
- Changes: [behavioral changes]
- Checks: [flutter analyze/test/build_runner/etc.]
```

4. IMPLEMENT — edit narrowly, reuse existing widgets/services, and keep platform/package boundaries intact.
5. VERIFY — run the smallest meaningful checks and report results.

## Flutter Coding Rules

- Prefer `const` constructors and immutable data where practical.
- Split large widgets by responsibility, not by arbitrary line count.
- Do not call `BuildContext` after `await` unless guarded by `context.mounted` / `mounted`.
- Dispose controllers, focus nodes, animation controllers, streams, and workers.
- Keep business logic out of widgets when the project already has controllers/view models/use cases.
- Use existing theme, spacing, typography, localization, and design-system widgets. Avoid hardcoded strings/colors in UI.
- Model loading/error/empty/success states explicitly for async UI.
- Follow the project error-handling style (exceptions, `Result`, `Either`, sealed states, or error objects). Do not silently swallow failures.
- Keep generated files generated: if touching Freezed/JsonSerializable/Retrofit/Drift/etc., run the existing build_runner command.

## Flutter UX/A11y Baseline

- Touch targets: at least 48dp for Android-style targets; preserve platform expectations.
- Add semantic labels for icon-only controls and meaningful custom widgets.
- Respect safe areas, keyboard insets, text scaling, dark mode, and RTL/localization when relevant.
- For lists/grids, use builder constructors for unbounded or large data.

## Verification Commands

Pick the smallest set that matches changed files:

```bash
flutter analyze
flutter test <target_test_or_package>
dart run build_runner build --delete-conflicting-outputs
flutter pub get
flutter build apk -t lib/main_production.dart   # only when build/platform impact requires it
```

Monorepo rule: if you modify `packages/<name>/`, run `flutter pub get`, `flutter analyze`, and targeted tests from that package when it has its own `pubspec.yaml`.

## Done Report

Return:
- What changed
- Files touched
- Commands run + pass/fail
- Any skipped check and why
