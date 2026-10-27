---
name: "flutter-performance"
description: "Investigate and optimize Flutter performance: jank, rebuilds, frame budget, startup, memory, images, lists, async work, profiling evidence, and before/after verification."
---

You are a Flutter performance investigator. Measure first, optimize second, and preserve behavior.

## Targets

Use this skill for:
- Jank, dropped frames, slow animations, scrolling lag
- Excessive rebuilds, expensive `build()` methods, state granularity issues
- Startup time, large assets/images, shader compilation, memory growth/leaks
- Slow async/data pipelines that affect UI responsiveness

## Golden Rule

Do not recommend "make it faster" changes without evidence. Name the bottleneck, the technique, and the expected trade-off.

## Investigation Flow

1. Reproduce: device/profile mode, screen/flow, data size, steps.
2. Measure: frame timing, rebuild logs, DevTools/performance trace if available, logs/screenshots from user if not.
3. Localize: UI rebuild/layout/paint, image/assets, async CPU work, IO/network, memory lifecycle, startup.
4. Choose the smallest targeted fix.
5. Verify with before/after evidence or the best available proxy.

## Common Flutter Techniques

| Symptom | Candidate fix |
|---|---|
| Large list jank | `ListView.builder`, item extent/prototype item, pagination, cache tuning |
| Whole screen rebuilds | Narrow state listeners (`Obx`, `Selector`, `BlocSelector`, providers), split widgets by state ownership |
| Animation choppy despite stable frame rate | Check for stepped quantization (`SteppedCurve`, `(t*N).floor()/N`); switch to continuous eased curves |
| Animation rebuilds subtree every tick | Move motion to paint phase: `CustomPaint` with `super(repaint: animation)` in a `RepaintBoundary` |
| Expensive paint | `RepaintBoundary` around stable expensive subtrees, reduce shadows/clips/opacity layers |
| Expensive layout | Avoid nested unbounded scrollables, reduce intrinsic sizing, constrain images/widgets |
| Image jank/memory | Resize/cache images, use thumbnails, `cacheWidth/cacheHeight`, avoid decoding huge assets on UI path |
| CPU work on UI isolate | Move heavy parsing/crypto/transforms to isolates (`compute`/Isolate.run`) |
| Startup slowness | Lazy init non-critical services, defer heavy work, audit sync IO before first frame |
| Leaks | Dispose controllers/subscriptions/workers; verify lifecycle of GetX/BLoC/Animation objects |

## Animation Jank Playbook

Traps to check, in order, when an interaction animation "lags" or "is not 60fps":

1. **Stepped quantization** — `(t * N).floor() / N` in painters or `SteppedCurve(k)` caps motion at N updates per duration (6 steps / 480ms = 12.5fps). Users perceive this as lag even at a perfect frame rate. Fix: continuous eased curves (`easeOutCubic` for expansion, `easeOut` fade, `easeOutBack` for bounce), keeping durations, colors, and geometry identical.
2. **Rebuild scope** — the interaction must not rebuild the screen/list. Riverpod: `select` with value-equal results (records, primitives, joined-key strings; identity for models without `==`); per-item cells watch only their own slice. Feedback state: `ValueNotifier` scoped to the overlay subtree, not widget-wide `setState`.
3. **Build-phase vs paint-phase animation** — continuous motion belongs in the paint phase: `CustomPaint` + `super(repaint: animation)` inside a `RepaintBoundary`, no `AnimatedBuilder`/`setState` per tick. Swap animated values as a single node + `FadeTransition`/`ScaleTransition` on one lazily-created controller — `AnimatedSwitcher` lays out two children per frame.
4. **IO on the interaction path** — debounce persistence (e.g. 200ms) so rapid taps never serialize synchronously on the UI isolate.

Widget-test proxies that pin 60fps behavior when no device is available:

- **Continuity**: after a value change, an animated value (e.g. `FadeTransition.opacity.value`) must strictly increase between two nearby `tester.pump()` frames — stepped curves hold equal values and fail.
- **Painter continuity**: paint with `AlwaysStoppedAnimation(t)` onto `TestRecordingCanvas` at two `t` values inside the same old step bucket; recorded draw commands must differ.
- **Rebuild scoping**: `debugOnRebuildDirtyWidget` records rebuilt widgets; interacting with one item must rebuild that item only.
- **Structure**: no `AnimatedSwitcher`/`AnimatedBuilder` in the hot animated subtree; `RepaintBoundary` + `CustomPaint` present.

Remember: debug builds JIT and run per-frame asserts — verify on-device FPS in profile mode (`flutter run --profile`) before and after.

## GetX/State Granularity Notes

- Keep `Obx` scopes as small as possible; do not wrap an entire page if only one label changes.
- Avoid mutating Rx collections without emitting when the UI depends on updates.
- Dispose workers/listeners in controller lifecycle.

## Anti-patterns

- Adding `const` everywhere as the only fix without proving rebuild cost.
- Introducing caches with no invalidation policy.
- Hiding jank by delaying UI or swallowing errors.
- Replacing architecture broadly when a local state/list/image fix is enough.

## Performance Plan Template

```markdown
## Flutter Performance Plan
- Symptom: [observable problem]
- Evidence: [trace/log/user repro/current code signal]
- Suspected bottleneck: [UI rebuild/layout/paint/IO/CPU/memory/startup]
- Technique: [specific optimization]
- Trade-off: [complexity/memory/cache invalidation/etc.]
- Checks: [how before/after will be verified]
```

## Verification Commands / Tools

```bash
flutter analyze
flutter test <affected_tests>
flutter run --profile -t <entrypoint>
```

When possible, use Flutter DevTools Performance/Memory views or `debugProfileBuildsEnabled`/rebuild diagnostics during investigation, then remove temporary diagnostics before finishing.

## Done Report

Include:
- Bottleneck found
- Optimization applied
- Before/after evidence or why measurement was limited
- Commands run and results
