# Archer FM — Project Status

> **Living project tracker.** Update this file after every meaningful work session and commit.
> Last updated: 2026-11-14
> Project status: Hero asset audit and transfer in progress
> Default branch: `main`

## 1. Project identity

- **Game name:** Archer FM
- **Repository:** `fadimatar112211-bit/Archer-fm`
- **Visibility:** Private
- **Legacy source project:** `fadimatar112211-bit/Archero_fm`
- **Relationship to legacy project:** Separate, clean project. The legacy repository must remain intact. Reuse only approved assets and useful references; do not copy its architecture wholesale.

## 2. Vision

Build a polished, mobile-first, Arabic-language multiplayer arena game inspired by the broad action-survival feel of Archero, while using original game systems and properly licensed or user-owned assets.

The central mode is a four-player Free-for-All PvP match. Each player controls one hero, builds and protects a castle through crystals, controls resource mines, and commands an automatically fighting monster force. The game should support online play and local four-device play over a Wi-Fi hotspot.

The goal is a complete, enjoyable, maintainable game—not merely a port or a build that compiles.

## 3. Confirmed gameplay requirements

### Match and victory
- Four real players per match; every player competes against the other three (no teams or alliances).
- Match lengths offered: 10, 20, 30, 45, or 60 minutes.
- If the match timer expires, the highest score wins.
- A match ends immediately when only one player still owns crystals.
- If scores tie at time-up, the player with more crystals wins.
- Players can attack opponents from the beginning of the match.
- Random matchmaking and private rooms with invite codes are required.
- Friends can be invited by username; room owner can remove a player before the match.
- Leaving a room before the match has no penalty; leaving an active match counts as a loss.

### Heroes and combat
- Reuse the four existing hero characters and their art from the legacy project, subject to asset review.
- Each player selects one hero before the match and keeps that hero for the whole match. Multiple players may select the same hero.
- Each hero has three associated weapons: one initially available and two unlocked through progression.
- Each hero has four special abilities unlocked at hero levels 1, 10, 20, and 30. The Ultimate is one of these four abilities, not a fifth ability.
- Hero level cap: 40. Hero progression happens outside matches only and is permanent.
- Combat is manual: each attack requires a separate player input; no automatic basic attacks.
- Five-hit combo; the fifth hit is stronger. A missed timing window resets the combo.
- Basic attacks do not consume energy.
- Weapons differ in damage, range, attack speed, and target count. All weapons can attack while moving.
- Abilities consume energy and have individual cooldowns. Multiple abilities may be used consecutively when available.
- Burn and poison can stack; freeze and stun temporarily disable a target. No special status resistances and no dodge system.
- All heroes have equal base HP at the same level; HP increases through permanent progression. HP does not regenerate automatically.
- On death, the hero loses 20% of current match resources, waits 10 seconds, then respawns at full HP with 5 seconds of temporary protection.

### Monsters
- Reuse the four existing monster types from the legacy project; do not add new types in the initial scope.
- Before a match, each player selects a free starting army of 20 monsters in any distribution among the four types. They appear near the player's castle when the match begins.
- Additional monsters can be purchased during the match using match resources. No fixed army cap; practical limits must be established through performance testing.
- All four types are purchasable from match start, with different prices and distinct stats/roles.
- Monsters move and fight automatically. They move in cohesive groups, but choose targets and fight independently.
- They seek the nearest enemy and can attack enemy heroes, monsters, and crystals. They automatically defend their owner's crystals.
- Monsters cannot attack a castle directly; its crystals must be destroyed first.
- Purchased monsters spawn beside their owner's castle.
- Dead monsters are permanently lost and must be replaced by purchasing new ones.
- Monster types are upgraded independently outside matches, up to level 40. Upgrades improve HP, attack, and movement speed.

### Castles and crystals
- Each player starts with one castle and seven crystals.
- Starting crystal HP values: 500, 700, 900, 1200, 1500, 1800, and 2200.
- Some crystals are exposed and some are inside walls.
- Any crystal can be attacked directly; outer crystals do not have to be destroyed first.
- When all a player's crystals are destroyed, that castle falls and disappears. The player remains in the match and can rebuild.
- Rebuilt crystals use the same HP values as the original crystals. Each successive rebuild costs more resources.
- Crystals can be rebuilt anywhere in the player's territory if the location is clear of obstacles and mines. Building is immediate after payment and can happen during combat.
- Rebuilt crystals can also be destroyed and rebuilt again.
- Maximum crystal count is seven; whether this means seven simultaneously active crystals or seven total placements is still to be confirmed.
- Current proposed rule: a new castle returns with the first rebuilt crystal. Separate castle construction cost/rules need final confirmation.

### Mines and match resources
- Eight neutral mines are distributed across the map, in small, medium, and large sizes.
- Capture requires remaining inside the mine's area for 10 seconds.
- If multiple players are in the area, capture progress pauses until only one remains. An opponent can capture an owned mine by completing the capture process.
- Owned mines keep producing resources while their owner is elsewhere.
- Mines cannot be destroyed. A player may control multiple mines simultaneously.
- Produced resource pickups must be physically collected by walking over/touching them; they are not automatically deposited.
- One match resource is used to buy monsters, rebuild crystals, and upgrade resource-carry capacity.
- Starting carry capacity: 500; maximum capacity can be permanently upgraded outside matches.
- Mine production rates, mine storage, pickup lifetime, carry-capacity progression, and economy values remain balancing work.

### Map and match world
- One large map layout, with randomized size and randomized placement of castles, mines, obstacles, and other elements each match.
- Four castles are distributed randomly and share the same design.
- Biomes include forests, deserts, snow, and volcanic areas.
- Include rivers, bridges, and water; water affects movement speed.
- Trees and rocks are indestructible. No terrain area grants combat bonuses.
- Random extra resources and chests can appear.
- Fog of war hides unexplored areas; areas remain revealed once discovered.
- Enemy monsters are shown only when nearby. Players start beside their own castle.
- A minimap is required. Crystals and mines remain represented on the minimap even when far away.

### Progression, equipment, and rewards
- Two separate currencies: match resources and permanent progression currency.
- Permanent currency earned from defeating monsters/enemies and destroying crystals is credited after the match. Players keep what they earned even if they lose.
- Permanent currency is used for hero, monster, equipment, and resource-capacity progression.
- Equipment slots: weapon, helmet, armor, boots, ring, and necklace.
- Equipment rarities: Common, Rare, Epic, Legendary, and Mythic.
- Equipment and weapons come from gameplay and chests. Duplicate items become upgrade materials; unwanted equipment can be sold.
- Equipment levels cap at 40. Each hero has a separate upgrade page; each monster type has its own page.
- Players may upgrade heroes and monster types they are not currently using.
- Different upgrade categories require their own materials; currency alone is insufficient.
- Chests contain equipment and weapons only.
- No ads, real-money purchases, paid battle pass, paid cosmetics, daily missions, or login rewards. The game is intended to be entirely free.

### Accounts and social
- Sign-in options: Google, Apple, or username/password.
- Each player has a username and profile picture.
- Friends list, friend requests, accept/decline, and username search.
- View an opponent's profile and statistics before a match.
- No match history, achievements, ranked mode, global leaderboard, or replay system in the initial requirements.
- No text chat, quick-chat signals, player reports, block list, online-player directory, or friend-online notifications.
- Matchmaking must match players who selected the same match duration.

### UI, audio, and accessibility
- Arabic language only for the initial release.
- Landscape mobile orientation.
- Main screen shows all four heroes, a prominent Play button, and a separate hero-upgrade entry.
- Separate pages for equipment, weapons, chests, and monster roster.
- Show overall account power.
- In-match HUD shows HP, resources, score, crystals, mines, and minimap.
- Players can adjust control button size and position.
- Movement control on the left; attack and ability controls on the right.
- Pre-match screen shows all four heroes and player names.
- Each player has a distinct color. Names appear above heroes; HP bars appear above heroes and monsters.
- Notify players when any player's crystal is destroyed; no mine-capture alert and no audio warning when own crystals are attacked.
- No damage numbers over enemies and no special last-minute effects.
- Music and sound effects can be toggled independently.

### Networking, offline LAN, and performance
- Online multiplayer is required.
- Local multiplayer over a Wi-Fi hotspot must support four real devices without internet; one device hosts the match and the others connect to it (implementation proposal).
- Match state must remain synchronized across connected devices.
- Local results/progress should be saved and synchronized to the account when internet access returns (implementation proposal).
- Online authoritative validation is required for damage, kills, score, resources, health, and movement to reduce cheating.
- Player progress must persist across uninstall/reinstall through account-based cloud saving.
- Target mid-range and lower-end devices with adaptive graphics quality.
- Cross-platform Android/iPhone progression sync is not currently required.
- No battery-saver mode or vibration feature.
- Future free content may add heroes, maps, monsters, and game modes.

## 4. Legacy assets and source review

Expected reusable assets from `Archero_fm`:
- Four hero characters and their artwork/animations.
- Four monster types and their artwork/animations.

Hero audit and transfer: the four heroes' 16 SVG animation files (idle, walk, attack, death) have been audited, copied, and verified under `assets/heroes/`. No legacy gameplay code was copied. The legacy repository did not show a clear root license file; ownership/licensing must be confirmed before public distribution. Monster assets have not yet been audited or copied.

Legacy repository: `https://github.com/fadimatar112211-bit/Archero_fm`

## 5. Balance and unresolved design decisions

A preliminary balance proposal exists in the planning discussion, but its numerical values are **not approved as final**. Do not implement proposed numbers as settled design without validation.

Still to decide or test:
- Exact hero base HP, per-level HP growth, hero movement speeds, weapon stats, attack timing, combo window, energy capacity/regeneration, ability costs, cooldowns, and effect durations.
- Monster base stats, prices, spawn limits/technical safeguards, and group-following behavior when the hero moves far from the castle.
- Mine distribution by size, production rates, storage, pickup lifetime, and carry-capacity upgrade curve.
- Crystal rebuild cost curve and precise new-castle rule.
- Whether the seven-crystal limit is simultaneous or lifetime total.
- Scoring values and anti-farming rules for repeated kills.
- What happens if all players lose every crystal, and the interaction between rebuilding and the “last player with crystals” match-ending rule.
- Minimum player count and exact matchmaking timeout/start behavior when fewer than four players join.
- LAN host migration/host disconnect handling and secure account progression synchronization.
- Whether the initial visual approach should be advanced 2D or 3D; choose after a mobile performance/quality prototype.
- Networking technology, backend, hosting, persistence schema, and anti-cheat architecture.

## 6. Implementation status

| Area | Status | Notes |
|---|---|---|
| New private GitHub repository | Done | `Archer-fm`, branch `main` |
| Product vision and core requirements | Documented | Based on confirmed planning decisions |
| Preliminary balance design | Not finalized | Numbers require simulation and playtesting |
| Legacy asset audit | Partial | Hero sprites audited and copied; other systems not audited |
| Engine/architecture decision | Not started | Art direction approved as colorful 3D/2.5D chibi; rendering engine and gameplay dimensionality still need a mobile prototype |
| Project scaffold | Not started | No game code committed yet |
| Gameplay implementation | Not started | No gameplay systems implemented |
| Backend/multiplayer | Not started | No networking code or services configured |
| Automated tests/build verification | Not started | No tests run in this repository |

## 7. Main development roadmap — work one system at a time

**طريقة العمل المعتمدة:** نقسم اللعبة إلى أنظمة/مراحل رئيسية واضحة. ننجز كل نظام بشكل مستقل قدر الإمكان، وقبل تنفيذه نرجع إلى المشروع القديم `Archero_fm` ونفحص الجزء المقابل فيه. نحدد ما هو جاهز وقابل لإعادة الاستخدام، وما يحتاج تعديل، وما يجب بناؤه من الصفر. لا نعيد كتابة شيء موجود وجاهز بلا داعٍ، ولا ننقل ملفات قبل فحصها واختبار توافقها.

لكل نظام نستخدم دورة العمل التالية:
1. تحديد نطاق النظام ومتطلباته المتفق عليها.
2. فحص النظام المقابل في `Archero_fm` والملفات المرتبطة به.
3. إعداد جرد واضح: **جاهز لإعادة الاستخدام / يحتاج تعديل / غير موجود ويُبنى جديداً / يحتاج قراراً**.
4. اعتماد خطة النقل أو إعادة البناء قبل التغيير.
5. تنفيذ النظام داخل `Archer-fm` مع الحفاظ على فصل الكود وتنظيمه.
6. اختبار النظام منفرداً، ثم اختبار تكامله مع الأنظمة السابقة.
7. تحديث حالة هذا النظام في هذا الملف وتسجيل الملفات والاختبارات ونتائجها وcommit.

### المراحل الرئيسية

| # | النظام الرئيسي | ما يشمله | حالة Archer FM | فحص Archero_fm |
|---|---|---|---|---|
| 1 | الأبطال | الشخصيات الأربعة، الرسومات، الحركات، الأنيميشن، خصائص كل بطل، الاختيار | تم تدقيق الأصول ونسخ 16 ملف SVG؛ تم اعتماد اتجاه فني كرتوني 3D/2.5D؛ برمجة النظام لم تبدأ | اكتمل فحص الكتالوج والرسومات؛ راجع `docs/heroes/HEROES_AUDIT.md` |
| 2 | الوحوش والجيش | الأنواع الأربعة، الرسومات والحركات، الذكاء الاصطناعي، التجمع، الاستهداف، الجيش الابتدائي والشراء | لم يبدأ | لم يبدأ |
| 3 | القتال والأسلحة والقدرات | الهجوم اليدوي، الكومبو، الأسلحة، الضرر، المدى، الطاقة، القدرات والتأثيرات | لم يبدأ | لم يبدأ |
| 4 | الخريطة والعالم | حجم الخريطة، المناطق الحيوية، العوائق، الأنهار والجسور والمياه، الضباب، الكاميرا | لم يبدأ | لم يبدأ |
| 5 | القلاع والكريستالات | تصميم القلاع، الكريستالات، الصحة، التدمير، سقوط القلعة وإعادة البناء | لم يبدأ | لم يبدأ |
| 6 | المناجم والموارد والاقتصاد | المناجم، السيطرة، إنتاج الموارد، التقاطها، المخزون، الأسعار والتكاليف | لم يبدأ | لم يبدأ |
| 7 | نظام المباراة وقواعد الفوز | مدة المباراة، النقاط، شروط النهاية، الإحياء، الانسحاب، تدفق المباراة | لم يبدأ | لم يبدأ |
| 8 | الأونلاين والغرف والأصدقاء | المطابقة، الغرف الخاصة، الدعوات، الأصدقاء، مزامنة اللاعبين وحالة المباراة | لم يبدأ | لم يبدأ |
| 9 | اللعب المحلي عبر Hotspot | استضافة جهاز، اتصال 4 أجهزة، مزامنة LAN، التعامل مع انقطاع المضيف | لم يبدأ | لم يبدأ |
| 10 | الحسابات والحفظ | تسجيل الدخول، الملف الشخصي، الحفظ السحابي، استعادة التقدم | لم يبدأ | لم يبدأ |
| 11 | التطوير الدائم والمعدات والصناديق | مستويات الأبطال والوحوش والمعدات، الندرة، المواد، الصناديق والعملات | لم يبدأ | لم يبدأ |
| 12 | واجهات اللعبة وتجربة المستخدم | الرئيسية، اختيار البطل والجيش، التطوير، HUD، الخريطة المصغرة، الإعدادات | لم يبدأ | لم يبدأ |
| 13 | الصوت والمؤثرات | الموسيقى، مؤثرات القتال والقدرات والبيئة، إعدادات الصوت | لم يبدأ | لم يبدأ |
| 14 | الأداء والأمان والاختبارات والإطلاق | تحسين الأجهزة الضعيفة، منع الغش، الاختبارات، البناء، التوافق والنشر | لم يبدأ | لم يبدأ |

### سجل فحص المشروع القديم لكل نظام

يُملأ هذا السجل عند بدء كل مرحلة، ولا نضع علامة «جاهز» إلا بعد فتح الملفات وفحصها فعلياً:

| النظام | ملفات Archero_fm التي فُحصت | الموجود الجاهز | ما يحتاج تعديل | ما سنبنيه جديداً | قرار النقل والاختبار |
|---|---|---|---|---|---|
| الأبطال | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| الوحوش | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| القتال والأسلحة | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| الخريطة | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| القلاع والكريستالات | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| المناجم والموارد | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| الواجهات والصوت | لم يُفحص بعد | — | — | — | بانتظار التدقيق |

### ترتيب التنفيذ المقترح

نبدأ بفحص الأبطال والوحوش لأنهما يتضمنان الأصول التي نعرف مسبقاً أننا نريد الاستفادة منها. بعد ذلك نثبت القتال والحركة والخريطة كأساس قابل للتجربة، ثم نبني القلاع والكريستالات والمناجم والاقتصاد، ثم نربط أنظمة المباراة والواجهات والتطوير، وبعدها نكمل الشبكات والحفظ والأمان والاختبارات الشاملة. يمكن تعديل الترتيب إذا كشف فحص الملفات عن اعتماد تقني يستدعي ذلك.

لا يعني هذا الترتيب أن كل نظام سيُنفذ بمعزل تام؛ سننشئ التكاملات الضرورية تدريجياً، لكن سنحافظ على حدود واضحة لكل نظام كي يسهل اختباره وتعديله.

## 8. Working rules

- Keep this repository separate from `Archero_fm`.
- Never delete or overwrite legacy content as part of the new project setup.
- Do not claim a feature is complete until implemented and tested.
- Clearly distinguish confirmed requirements, proposals, and unresolved decisions.
- Prefer original code and approved assets; do not copy proprietary Archero code or art.
- Record each meaningful change, test result, known defect, and next action in this file.
- Update this tracker in the same work batch as related code changes whenever practical.

## 9. Latest checkpoint

- Repository verified as private and accessible.
- `main` was empty at initialization.
- `PROJECT_STATUS.md` is the project tracker; `docs/heroes/HEROES_AUDIT.md` records the first system audit.
- Hero asset audit completed: 16 SVG files copied and verified in `assets/heroes/`.
- User approved the generated hero-selection concept as the visual direction: colorful, polished 3D/2.5D chibi fantasy heroes, with four distinct identities (green archer, red fire knight, purple shadow hunter, blue storm guardian). This approves the art direction, not the final production assets or UI implementation.
- Existing SVG sprites are retained as legacy source/reference assets; they do not yet match or implement the approved 3D/2.5D look.
- No hero runtime code, game engine scaffold, backend, or hero tests have been implemented yet.
- Balanced Ranger first-pass character sheet generated and accepted as the visual reference: green hooded cloak, white hair, blue eyes, gold-trimmed leather armor, quiver, and green energy bow; front/three-quarter/side/back plus idle, walk, attack, and defeat pose references.
- This is a concept sheet, not production-ready animation or an implemented game asset. No runtime code or in-game animation test exists yet.
- Next action: inspect the legacy ranger SVG frames against this design, define the production asset pipeline (2D skeletal/2.5D vs true 3D), then build a small rendering prototype.
