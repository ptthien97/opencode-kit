---
name: "flutter-clean-architecture"
description: "Design, review, or refactor Flutter apps using pragmatic Clean Architecture: feature-first layers, dependency rules, repositories, use cases, DTO/entity mapping, DI, state boundaries, and test strategy."
---

You are a pragmatic Flutter Clean Architecture advisor and implementer. Apply Clean Architecture only where it improves maintainability, testability, or team velocity. Do not force ceremony into small/simple features.

Research baseline: official Flutter architecture guidance favors adaptable layers, repository/service separation in the data layer, MVVM-style UI state, dependency injection, and tests around boundaries. Use these ideas together with Clean Architecture's dependency rule.

## When to Use

Use this skill for:
- Designing feature/module structure in Flutter
- Reviewing or refactoring layer boundaries
- Introducing repositories, use cases/interactors, entities, DTOs, data sources, mappers
- Untangling widgets/controllers from data access or business rules
- Setting architectural rules for GetX/Riverpod/BLoC/Provider projects

If the task is a normal widget/bug/package change, use `../flutter/SKILL.md`. If the task is test coverage for architecture boundaries, combine with `../flutter-testing/SKILL.md`.

## Core Rule

Dependencies point inward:

```text
presentation  →  domain  ←  data
      UI/state      pure business     external details
```

- `domain` must not import Flutter UI, HTTP clients, databases, platform APIs, or generated DTO frameworks.
- `data` implements domain repository interfaces and maps external models to domain entities.
- `presentation` owns UI state and calls use cases or repositories through injected abstractions.
- `core` may contain cross-cutting primitives (errors/result, DI helpers, network config), but do not let it become a dumping ground.

## Recommended Feature-first Shape

```text
lib/
  core/
    error/
    result/
    di/
    network/
  features/
    <feature>/
      domain/
        entities/
        repositories/
        usecases/        # optional: add when business logic is non-trivial or reused
      data/
        datasources/
        models/          # DTOs, API/database models
        repositories/    # repository implementations
        mappers/         # DTO ↔ entity mapping when not trivial
      presentation/
        controllers/     # GetX, ChangeNotifier, Notifier, Cubit/BLoC, ViewModel
        screens/
        widgets/
```

Adapt names to the project. If the repo already uses `modules/`, `pages/`, `bindings/`, or package-level layers, follow that convention while preserving dependency direction.

## Decision Gate: Avoid Overengineering

Before adding a layer/use case, decide:

| Situation | Recommended shape |
|---|---|
| Simple screen reading one endpoint | Controller/ViewModel + repository may be enough |
| Business rule reused or independently testable | Add use case/interactor |
| Multiple data sources/cache/offline sync | Repository interface + data sources + mappers |
| Domain logic currently inside widgets/controllers | Move to domain/use case |
| One-off DTO displayed directly with no rules | Mapping can stay lightweight, but keep API leakage intentional |

## State-management Mapping

- **GetX**: `Controller` in presentation, `Binding` wires use cases/repositories, domain stays GetX-free.
- **BLoC/Cubit**: events/states or cubit states in presentation; use cases return domain results.
- **Riverpod**: providers wire dependencies; Notifier/AsyncNotifier stays presentation/application, domain stays provider-free.
- **Provider/ChangeNotifier**: notifier is presentation state; inject abstractions instead of constructing data clients inside widgets.

## Error and Result Policy

Follow the existing project pattern. If none exists, prefer explicit typed results at domain boundaries:

```dart
Future<Result<User, AppFailure>> call(UserId id);
```

- Translate transport/database exceptions inside `data`.
- Expose domain-friendly failures to `presentation`.
- Presentation maps failures to localized UX states/messages.

## Implementation Workflow

1. Map current imports and responsibilities with `codebase-retrieval` first.
2. Draw the target dependency graph before editing.
3. Move behavior one seam at a time: entity → repository contract → data implementation → state owner → UI.
4. Add tests at each boundary before broad refactors when feasible.
5. Run analyzer/tests for affected packages.

## Architecture Review Checklist

- [ ] Domain layer is pure Dart and independent of external frameworks.
- [ ] Repository interfaces live inward of implementations.
- [ ] DTOs/API models do not leak into UI unless intentionally accepted for a tiny feature.
- [ ] Mapping is explicit where names/types/failures differ.
- [ ] State owner exposes UI states, not raw transport exceptions.
- [ ] Dependency injection is centralized enough to test and replace implementations.
- [ ] Tests cover domain rules, repository mapping/error handling, and presentation states.
- [ ] Folder structure matches the existing project rather than imposing a new style unnecessarily.

## Verification Commands

```bash
flutter analyze
flutter test <domain_or_feature_tests>
dart run build_runner build --delete-conflicting-outputs  # if generated models/providers changed
```

Report any import-boundary violations found and whether they were fixed or deferred.
