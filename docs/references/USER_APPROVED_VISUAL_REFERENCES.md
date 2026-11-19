# Archer FM — User-Approved Visual References (AUTHORITATIVE)

Status: the user supplied the exact reference images in the 2026-11-19 conversation. These images supersede all earlier generated concepts, placeholder renders, procedural prototypes, and inferred design briefs. Do not generate substitutes or reinterpret the approved designs.

## Exact hero reference images

The four square images supplied by the user are the only approved visual targets:
- Storm: `assets/references/approved/heroes/storm.jpg` — white/silver spiky hair, blue eyes, blue-and-gold armor/cloak, lightning crystal spear/staff and blue energy.
- Flame: `assets/references/approved/heroes/flame.jpg` — vivid red/orange spiky hair, red/orange eyes, red cloak, dark armor with gold trim, flaming sword and fire effects.
- Ranger: `assets/references/approved/heroes/ranger.jpg` — brown hair, green hood, green eyes, green-and-gold armor, glowing green bow and arrow.
- Shadow: `assets/references/approved/heroes/shadow.jpg` — silver/lavender hair, purple eyes, dark hood and face covering, black/purple armor and twin violet energy blades.

The four original hero attachments contain JPEG data, despite the original attachment filenames ending in `.png`. The repository destination uses the correct `.jpg` extension; the original bytes must remain unchanged.

The artwork in each complete image (including its composition and character details) is the reference. For in-game 3D character assets, reproduce the character itself faithfully; do not copy the promotional logo/background into the 3D model. Do not alter face, hairstyle, eye color, costume, palette, weapon silhouette, or signature effects.

## Exact monster reference

The user supplied one cropped reference sheet showing exactly four enemy designs. Store it at:
- `assets/references/approved/monsters/monster_types.png`

Left-to-right order and labels on the source image:
1. Green goblin-like sword enemy — Arabic label: `عدو عادي`.
2. Skeleton dual-blade enemy — Arabic label: `عدو سريع`.
3. Horned heavy armored enemy with oversized spiked mace — Arabic label: `عدو ثقيل`.
4. Purple hooded masked enemy with violet energy blades — Arabic label: `عدو متسلل`.

These exact four source designs replace the earlier Runner/Tank/Stalker/Ranged invented visual concepts. Existing gameplay roles/stats may only be mapped to these four after an explicit code/spec review; do not change their appearance to fit earlier names.

## Mandatory production rules

1. These user images are the single source of truth for hero and monster appearance.
2. No AI-generated replacement images, generic web images, concept-art approximations, or procedural placeholder designs may be presented as the approved references.
3. Before modeling, inspect the exact source image. Model each character to match it, including face, hair/headgear, body proportions, armor/clothing, weapons, materials, colors, and effects.
4. Build actual 3D assets with real geometry/materials. Rig and animate only after the base model visually matches.
5. Review front, three-quarter, side, and back views against the source; front-facing resemblance alone is insufficient.
6. Keep the original reference files byte-for-byte unchanged. Do not crop, recolor, retouch, or recompress the authoritative files.
7. Do not claim a model is approved or reference-matched until there is a documented side-by-side review.
8. Retire or clearly mark older conflicting visual briefs and generated prototypes as superseded; do not delete source work until replacement assets are reviewed.

## Binary asset ingestion status — STILL PENDING

The exact original binary attachments are accessible in the current ChatGPT working session, and a ZIP package has been prepared for upload with the exact original bytes and the repository folder structure. However, the available GitHub connector in this session exposes text-file writes and Git object APIs but no file-stream/binary upload bridge from the attached files. Therefore the five binary assets have **not** yet been committed to GitHub.

Required destinations:
- `assets/references/approved/heroes/storm.jpg`
- `assets/references/approved/heroes/flame.jpg`
- `assets/references/approved/heroes/ranger.jpg`
- `assets/references/approved/heroes/shadow.jpg`
- `assets/references/approved/monsters/monster_types.png`

Do not create fake image files or substitute thumbnails. Keep this status pending until all five exact binary files are visible in the Git tree.


## Latest approved reference set — consolidated update (2026-11-20)

The user subsequently supplied and approved a consolidated set of three visual references. This section is the latest authority where older notes above describe a different image packaging or earlier paths.

### 1. Hero appearance sheet
- Repository image: `assets/references/approved_all/hero_roster_concept.jpg`
- Defines the four playable hero appearances in one sheet:
  - Ranger: brown spiky hair, green eyes, green hood/cloak and armor, bow and green energy.
  - Flame Knight: vivid red/orange hair, red/orange armor and fire identity, sword.
  - Shadow: purple hood and dark armor, violet eyes/energy blades.
  - Storm: white hair, blue eyes, blue-and-white outfit/armor and blue lightning energy.
- This exact image is the appearance authority for all four heroes. Do not substitute generated images or the older separate-image path list above.

### 2. Enemy appearance sheet
- Repository image: `assets/references/approved_all/archer_fm_monsters_reference.png`
- Defines exactly four enemy appearances, left to right:
  1. Green goblin-like sword wielder — ordinary enemy.
  2. Skeleton with dual blades — fast enemy.
  3. Large horned armored brute with oversized spiked mace — heavy enemy.
  4. Purple hooded masked fighter with violet energy blades — infiltrator/ranged-style enemy as labelled in the supplied reference.
- The source image's four designs are authoritative. Do not redesign them to match older provisional Runner/Tank/Stalker/Ranged terminology; map gameplay roles only after reviewing the actual game specification and code.

### 3. In-match gameplay appearance and HUD
- Repository image: `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png`
- Defines the target landscape gameplay presentation: elevated close three-quarter/isometric camera; richly detailed stone-and-grass arena with river, wooden bridge, rocks, ruins and vegetation; large glowing crystal structures; readable hero and troop scale; visible monster combat; health bars, level badges and damage numbers; top-left player portrait/name/HP/level; top-center match timer and objective counters; top-right minimap and settings; bottom-left movement joystick; bottom-right attack and skill buttons; consumable/potion control.
- This screenshot is a presentation/layout target only. Its sample timer, player levels, health, crystal counts, damage values, potion count, troop count and exact positions are not fixed game rules.
- The gameplay screenshot does not replace the hero or enemy appearance sheets. Use the hero sheet for hero design, the enemy sheet for enemy design, and this screenshot for camera, arena, composition, combat readability and HUD.
- Detailed implementation requirements and acceptance checklist are recorded in `VISUAL_DIRECTION_PLAN.md` under **Approved gameplay-result reference — detailed implementation specification (2026-11-20)**.

### Repository verification note
At the time this consolidated update was written, the three image paths above were present in the `ranger-reference-work` Git tree. Keep the original image bytes unchanged. Do not delete duplicate/older reference files until the approved three images are verified and a deliberate cleanup is requested.
