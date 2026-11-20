# Archer FM — Stage One Camera & Visibility Pack

Source snapshot: `ranger-reference-work` audit commit `3c2c8f50e89b8362cbeca4d80bc0287cb4de1b8e`.

This is a focused, lightweight source pack for Stage One (Baseline Audit: camera, projection, viewport framing, world visibility, and pointer/world coordinate consistency). It intentionally excludes hero/monster models, textures, audio, generated assets, build outputs, and unrelated screens.

## For the coding assistant
1. Read `VISUAL_DIRECTION_PLAN.md` and the Stage One entries in `PROJECT_PROGRESS.md`.
2. Work ONLY on Stage One camera/visibility scope. Do not redesign heroes, monsters, map art, combat, progression, or UI.
3. Inspect all included camera, painter, projection, world, and test files before editing.
4. Resolve the documented API mismatch between `arena_painter.dart` and `arena_camera.dart`; preserve one shared projection/transform for rendering and input.
5. Keep the requested default zoom target at 1.15 with safe world-bound clamping, but verify the actual current implementation and existing design constraints before changing it.
6. Update/add focused tests for zoom, visible world bounds, camera movement/smoothing, letterboxing, and pointer-to-world round trips.
7. Do not claim full-project Flutter analyze/test/build success from this partial pack. If dependencies or source files are missing, list them precisely. Run full checks only against a complete local project checkout.
8. Return the complete modified files, a concise change report, and exact test commands/results. Do not claim Stage One complete without the required real gameplay/emulator/release evidence.

## Important limitation
This pack is deliberately not a complete Flutter checkout. Some imported application files and assets are omitted to keep it small. Use it for focused source editing/review; integrate the returned files into the full project before running full builds and tests.
