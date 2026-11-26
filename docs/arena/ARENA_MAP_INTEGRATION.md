# Arena Map v1 — integration status

This branch adds the first in-app 2.5D presentation of the four-player arena design.

## Included in this change
- A dedicated Flutter arena screen at `lib/game/arena/arena_map_screen.dart`.
- Isometric/diamond projection for the arena, central river, eight bridges, four castle zones, 28 crystal markers, eight tower markers, five control points, monster-camp markers, and the central drake.
- Pan/zoom through Flutter's `InteractiveViewer`.
- An entry point from the existing hero viewer AppBar. The existing hero viewer and hero asset pipeline remain intact.
- A widget test for opening and rendering the map screen.

## Design values represented
- 96 × 96 world-unit arena, centered at (0, 0).
- Four player sides: south, east, north, west.
- Seven crystals per player (28 total).
- Eight bridges: four main crossings and four flank crossings.
- Eight towers, 17 monster camps, and five control points.

## Important scope boundary
This is the first visual integration, not a completed match runtime. This screen currently draws a 2.5D map preview from the design coordinates. It does not yet load the supplied `nav_grid.txt`, `height_map.csv`, or full JSON package at runtime, and it does not yet connect movement, A* pathfinding, collision, destructible crystals, monster AI, tower attacks, multiplayer synchronization, or the live 3D hero actors to this arena. Those require the gameplay world/runtime layer, which is not currently the app's home screen (the current app boots into the hero animation viewer).

## Next gameplay integration steps
1. Bundle and load the original JSON, navigation grid, and height map as versioned arena assets.
2. Port and test A* navigation, terrain costs, line-of-sight, collision, and crystal-destruction repathing.
3. Replace the preview painter's symbolic structures with world entities and 2.5D/3D render components.
4. Connect hero movement/combat, units, monsters, towers, crystals, and match rules.
5. Run the full Android build and gameplay tests.
