# Archer FM — User-Approved Visual References (AUTHORITATIVE)

Status: the user supplied the exact reference images in the 2026-11-19 conversation. These images supersede all earlier generated concepts, placeholder renders, procedural prototypes, and inferred design briefs. Do not generate substitutes or reinterpret the approved designs.

## Exact hero reference images

The four square images supplied by the user are the only approved visual targets:
- Storm: `assets/references/approved/heroes/storm.png` — white/silver spiky hair, blue eyes, blue-and-gold armor/cloak, lightning crystal spear/staff and blue energy.
- Flame: `assets/references/approved/heroes/flame.png` — vivid red/orange spiky hair, red/orange eyes, red cloak, dark armor with gold trim, flaming sword and fire effects.
- Ranger: `assets/references/approved/heroes/ranger.png` — brown hair, green hood, green eyes, green-and-gold armor, glowing green bow and arrow.
- Shadow: `assets/references/approved/heroes/shadow.png` — silver/lavender hair, purple eyes, dark hood and face covering, black/purple armor and twin violet energy blades.

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
6. Keep the original reference files unchanged. Do not crop, recolor, retouch, or recompress the authoritative files.
7. Do not claim a model is approved or reference-matched until there is a documented side-by-side review.
8. Retire or clearly mark older conflicting visual briefs and generated prototypes as superseded; do not delete source work until replacement assets are reviewed.

## Binary asset ingestion status

The exact image files were attached in the ChatGPT conversation. Their original attachment filenames were:
- Hero images: `1000236743.png` (Storm), `1000236707.png` (Flame), `1000236705.png` (Ranger), `1000236706.png` (Shadow).
- Monster crop: `archer_fm_monsters_reference.png`.

The repository paths above are the required destinations. Do not create fake image files or substitute thumbnails. If the current GitHub upload interface cannot transfer binary attachments, report that blocker explicitly and leave the references marked pending binary ingestion; do not claim they have been committed.
