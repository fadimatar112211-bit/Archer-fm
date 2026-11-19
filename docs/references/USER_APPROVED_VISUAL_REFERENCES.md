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
