# Hero validation gate

The release gate is `flutter pub get`, `flutter analyze`, and `flutter test`.

Ranger, Flame and Shadow currently ship 8 states × 8 directions (64 clips and 64 atlases per hero). Storm's static GLB is not yet a rigged, eight-direction sprite runtime asset, so Storm must remain blocked until its rigged source, renders, manifest and atlases are committed.

The combat panel is a deterministic training-target sandbox. It does not prove production arena collision, enemy AI, multiplayer or match progression integration.
