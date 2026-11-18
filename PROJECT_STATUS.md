# Archer FM — Project Status

> **Living project tracker.** Update this file after every meaningful work session and commit.
> Last updated: 2026-11-18
> Project status: Match map, mines/economy, castles/crystals, permanent progression, online rooms/friends and four-device hotspot implemented; combat audited with open spec gaps; UI/sound/final release work remain; cloud save/host migration and device testing remain
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

Monster audit and transfer: the four legacy types (runner/tank/stalker/ranged) were audited from the old project's catalog and stat triangle and reused 1:1 (no new types). Their artwork/animations were not available in this environment, so the in-game monsters are drawn procedurally by `ArenaPainter` (body, limbs, weapon, real walk/idle/attack/death cycles) instead of copied assets. Swapping in the legacy SVGs later only touches the painter, not the simulation.

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
- Final rendering direction: 2.5D sprite sheets rendered from a consistent 3D Chibi source model; runtime engine remains undecided.
- Networking technology, backend, hosting, persistence schema, and anti-cheat architecture.
- Combat/spec gaps from the step-3 audit (2026-11-18) are now **resolved**: freeze and stun exist as real disables in `GameWorld` (movement/attacks/windups stop), and the dodge API/button/i-frames/combo-cancel were removed while the GLB dodge animation asset was left untouched. Durations/sources are documented balance placeholders (see §31). The third audit item — three weapons per hero unlocked by progression — was resolved in step 12 at the user's explicit clarification: they are chosen **before** the match, one starting plus two at hero levels 10 and 20 (see §32).

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
| 2 | الوحوش والجيش | الأنواع الأربعة، الرسومات والحركات، الذكاء الاصطناعي، التجمع، الاستهداف، الجيش الابتدائي والشراء | منفّذ داخل نموذج المعركة الحالي: 4 أنواع، جيش 20، شراء، موت دائم، ترقية حتى 40، رسم وحركة إجرائية (لا توجد قلاع بعد) | فُحصت الأدوار والإحصاءات القديمة؛ أصول الوحوش لم تكن متاحة فاعتُمد البديل الإجرائي |
| 3 | القتال والأسلحة والقدرات | الهجوم اليدوي، الكومبو، الأسلحة، الضرر، المدى، الطاقة، القدرات والتأثيرات | تم تدقيقه (2026-11-18): هجوم يدوي، كومبو 100/110/120/135/155 بنافذة 1800ms، 4 أسلحة مختلفة، 16 قدرة بأقفال 1/10/20/30 وطاقة/تبريد، حرق وسم يتراكمان، ضرر متزامن مع أحداث الأسلحة — فجوتان مفتوحتان في §5 (انظر §31) | اكتمل الفحص: لا نظام قتال قابل للنقل؛ بُني من الصفر (انظر §19–§24 و§31) |
| 4 | الخريطة والعالم | حجم الخريطة، المناطق الحيوية، العوائق، الأنهار والجسور والمياه، الضباب، الكاميرا | تم (2026-11-18): خريطة كبيرة مولَّدة عشوائياً، 4 بيومات، نهر وجسران، ماء يبطئ، أشجار/صخور مانعة، ضباب دائم، كاميرا تتبع، خريطة مصغرة، رؤية أعداء بالمسافة — 19 اختباراً | اكتمل الفحص: لا نظام خرائط قابل للنقل (انظر §26) |
| 5 | القلاع والكريستالات | تصميم القلاع، الكريستالات، الصحة، التدمير، سقوط القلعة وإعادة البناء | تم (2026-11-18): 4 قلاع × 7 كريستالات بقيم HP المؤكدة، 4 مكشوفة و3 داخل الجدران، تدمير مباشر بأي ترتيب، سقوط واختفاء القلعة، إعادة بناء في الإقليم بتكلفة متصاعدة ونفس HP، عودة القلعة بأول كريستال — 18 اختباراً | اكتمل الفحص: `assets/wall.svg` ورسم جدار بيئي فقط، لا نظام قلاع (انظر §28) |
| 6 | المناجم والموارد والاقتصاد | المناجم، السيطرة، إنتاج الموارد، التقاطها، المخزون، الأسعار والتكاليف | تم (2026-11-18): 8 مناجم 3/3/2، سيطرة 10 ثوانٍ مع إيقاف عند التعدد، استرجاع منجم مملوك، إنتاج مستمر، موارد أرضية تُلتقط باللمس بسعة 500، HUD ومؤشرات — 19 اختباراً | اكتمل الفحص: `coin_pickup_resolver.dart` فقط (انظر §27) |
| 7 | نظام المباراة وقواعد الفوز | مدة المباراة، النقاط، شروط النهاية، الإحياء، الانسحاب، تدفق المباراة | تم (2026-11-18): 5 مدد مؤكدة، انتهاء بالوقت أو بآخر لاعب يملك كريستالات، تعادل بالنقاط ثم الكريستالات، خروج من الغرفة بلا عقوبة وخروج من المباراة خسارة (انظر §30) | المشروع القديم لا يضم نظام مباراة قابل للنقل |
| 8 | الأونلاين والغرف والأصدقاء | المطابقة، الغرف الخاصة، الدعوات، الأصدقاء، مزامنة اللاعبين وحالة المباراة | تم (2026-11-18): مطابقة بنفس المدة، غرف برموز دعوة، دعوة بالاسم، إزالة اللاعب من المالك، أصدقاء وطلبات وبحث، خادم حاسم يمنع الغش في الضرر/القتل/النقاط/الموارد/الصحة/الحركة — 12 اختباراً (انظر §30) | لا يوجد نظام شبكة قابل للنقل؛ بُني جديداً |
| 9 | اللعب المحلي عبر Hotspot | استضافة جهاز، اتصال 4 أجهزة، مزامنة LAN، التعامل مع انقطاع المضيف | تم (2026-11-18): استضافة على شبكة الهاتف، اتصال 4 أجهزة بعنوان المضيف، نفس الخادم الحاسم ومزامنة اللقطات، حفظ النتائج محلياً عند الانقطاع — انظر §30 للحدود | لا يوجد نظام شبكة قابل للنقل |
| 10 | الحسابات والحفظ | تسجيل الدخول، الملف الشخصي، الحفظ السحابي، استعادة التقدم | جزئي (2026-11-18): حسابات اسم/كلمة مرور محلية، ملف شخصي وإحصائيات، أصدقاء وطلبات، نتائج معلّقة تُزامن عند عودة الإنترنت؛ الحفظ السحابي عبر حساب (Google/Apple) لا يزال مفتوحاً في §5 | لا يوجد نظام حسابات قابل للنقل |
| 11 | التطوير الدائم والمعدات والصناديق | مستويات الأبطال والوحوش والمعدات، الندرة، المواد، الصناديق والعملات | تم (2026-11-18): عملة دائمة منفصلة تُصرف بعد المباراة، 6 فتحات و5 ندرات، معدات حتى مستوى 40، مكررات→خامات وبيع، صناديق تُلحظ باللمس، صفحات الأبطال/الوحوش/المعدات/الأسلحة/الصناديق والقوة، خامات مستقلة لكل فئة، حفظ متوافق للخلف — 33 اختباراً جديداً | بُني بالكامل؛ المشروع القديم لا يضم نظام تطوير بمواد مستقلة (انظر §29) |
| 12 | واجهات اللعبة وتجربة المستخدم | الرئيسية، اختيار البطل والجيش، التطوير، HUD، الخريطة المصغرة، الإعدادات | تم (2026-11-18): واجهة رئيسية أفقية مستوحاة من Archero ببطل 3D في المنتصف وتنقل بالسحب يميناً/يساراً بين المتجر والأبطال والتطوير؛ اختيار البطل والجيش والسلاح قبل المباراة (3 أسلحة لكل بطل بمستويات فتح 1/10/20)؛ شاشة إعدادات تحكم عربية محفوظة؛ HUD والخريطة المصغرة من الأنظمة السابقة — 13 اختباراً جديداً ولقطتان جديدتان (انظر §32) | بُنيت الواجهات جديداً؛ المشروع القديم يضم قائمة رأسية وHUD مبسطاً بلا بطل 3D أو PageView أو نظام أسلحة، فلم يُنقل كود واجهة (انظر §32) |
| 13 | الصوت والمؤثرات | الموسيقى، مؤثرات القتال والقدرات والبيئة، إعدادات الصوت | لم يبدأ | لم يبدأ |
| 14 | الأداء والأمان والاختبارات والإطلاق | تحسين الأجهزة الضعيفة، منع الغش، الاختبارات، البناء، التوافق والنشر | لم يبدأ | لم يبدأ |

### سجل فحص المشروع القديم لكل نظام

يُملأ هذا السجل عند بدء كل مرحلة، ولا نضع علامة «جاهز» إلا بعد فتح الملفات وفحصها فعلياً:

| النظام | ملفات Archero_fm التي فُحصت | الموجود الجاهز | ما يحتاج تعديل | ما سنبنيه جديداً | قرار النقل والاختبار |
|---|---|---|---|---|---|
| الأبطال | لم يُفحص بعد | — | — | — | بانتظار التدقيق |
| الوحوش | كتالوج الأنواع الأربعة وإحصاءاتها النسبية من المشروع القديم (لم تُنزّل الأصول هنا) | الأدوار، التدرّج النسبي، فكرة الجيش الابتدائي والشراء | أسماء/أرقام لتناسب مقياس Archer FM | رسم وحركة إجرائية + ذكاء اصطناعي كامل | منفّذ ومُختبر داخل المعركة الحالية |
| القتال والأسلحة | `lib/game/combat/combo.dart`, `hero_kit.dart`, `lib/game/world/game_world.dart`, `lib/game/game_screen.dart`, `docs/game/ranger_combat.md`, `docs/game/flame_combat.md`, `docs/game/shadow_combat.md`, `docs/game/storm_combat.md`, `docs/game/special_abilities.md` | هجوم يدوي، كومبو 100/110/120/135/155% (1800ms)، 4 أسلحة بضرر/مدى/سرعة/عدد أهداف مختلفة وتهاجم أثناء الحركة، طاقة/تبريد لكل قدرة، 16 قدرة بأقفال 1/10/20/30، حرق وسم (DoT)، مزامنة الضرر مع أحداث weapon-release، بدون هجوم تلقائي أو مقاومات حالة | لا يوجد نظام قتال/قدرات قابل للنقل في المشروع القديم | منفّذ ومُختبر في Archer FM؛ فُحص مقابل المواصفات. ثلاثة أسلحة لكل بطل تُختار قبل المباراة (الخطوة 12، §32). فجوتا التجميد/الشلل والمراوغة حُسمتا بعد ذلك: `hell_burst` يشل 700ms، و`static_field` يجمّد 900ms، وكلاهما يوقف الحركة والهجوم ويلغي الاستعداد؛ ولا يوجد زر أو API للمراوغة (§31). |
| الخريطة | `lib/world_theme.dart`, `lib/player_movement.dart`, `ROADMAP.md`, `PROJECT_FILE_INVENTORY.md` | ألوان 6 عوالم في `world_theme.dart` كمرجع بصري فقط | لا شيء قابل للنقل | حجم الخريطة والبيومات والأنهار/الجسور والماء والعوائق والضباب والكاميرا والخريطة المصغرة | تم الفحص؛ لا نظام خرائط/مناجم/قلاع في المشروع القديم، فبُنيت الخريطة من الصفر (تفاصيل §26) |
| القلاع والكريستالات | `assets/wall.svg`, `lib/combat_painters.dart` | `wall.svg` (جدار حجري 64×64) ورسم جدران حجرية خلفية في المشروع القديم، وكريستال سهم بعيد (ليس كريستال قلعة) | لا شيء قابل للنقل كنظام | القلاع السبعة، HP، التدمير، السقوط، الإقليم، إعادة البناء المتصاعدة | تم الفحص؛ لا نظام قلاع/كريستالات في المشروع القديم، فبُني جديداً برسم إجرائي (تفاصيل §28) |
| المناجم والموارد | `lib/coin_pickup_resolver.dart`, `test/coin_pickup_resolver_test.dart`, `assets/coin.svg` | فحص تقارب بسيط للالتقاط بنصف قطر 34 | لا شيء قابل للنقل كبنية | المناجم والسيطرة والإنتاج والسعة والاقتصاد | تم الفحص؛ أُعيد استخدام قاعدة الالتقاط (34) داخل نظام المناجم دون نسخ الملف، والباقي بُني جديداً (§27) |
| الواجهات والصوت | `lib/main.dart`, `lib/game_screen.dart`, `test/widget_test.dart`, `test/shop_test.dart`; و`lib/audio_service.dart` مسجّل للخطوة 13 | قائمة رئيسية رأسية ببطاقات أبطال، شاشة اختيار بطل، HUD مبسط مبني بـStack مع عصا تحكم وأزرار، ومتجر عملة بسيط | لا يوجد بطل 3D ولا تنقل أفقي ولا اختيار سلاح قبل المباراة؛ البنية مرتبطة بعارض SVG ومؤقتات قديمة | واجهة أفقية بـPageView وبطل GLB مجلد في المنتصف، شاشة اختيار جيش/سلاح، شاشة إعدادات تحكم محفوظة | فُحصت الملفات؛ لم يُنقل كود واجهة، بُني جديداً (تفاصيل §32). الصوت ترك للخطوة 13 |

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
- User instruction: do not test or present the Balanced Ranger as complete until the character is fully implemented; then run a full test on the Android emulator/device setup referenced in the legacy Archero_fm project files. Re-inspect the old project's emulator configuration/instructions at that stage and verify the same emulator is usable with Archer FM.
- Legacy ranger animation files have now been inspected: idle, walk, attack, and death each use a 384×96 SVG canvas representing four 96×96 frames; idle/walk/attack use the green cloak/leather/gold palette. They are useful 2D motion/reference assets, but not the approved polished 3D/2.5D production character.
- Important emulator finding: the legacy repository contains a GitHub Actions workflow that builds/tests an APK on Ubuntu, but no checked-in Android AVD/emulator configuration or emulator launch/test step was found. At the final test gate we must either connect to the user's Android emulator or configure a reproducible emulator in CI; do not claim an emulator is already configured in the old repository.
- Rendering pipeline decision is now fixed: use 2.5D characters rendered from a consistent 3D chibi model into optimized transparent sprite sheets (not real-time 3D in gameplay). This preserves the approved 3D look while reducing runtime/GPU cost for mid- and low-range phones and keeping the current 2D-oriented project direction viable.
- Ranger production target: orthographic game-camera renders, consistent lighting/materials/pivot/scale, 8-direction views where gameplay requires directional facing, with idle/walk/attack/death animation sets. Start with a small performance/visual prototype before generating the full set.
- Next action: define the sprite-sheet technical specification and implement a small renderer/asset preview workflow; then produce the Ranger's final animation set. Android emulator testing remains the final completion gate.


## 10. Latest work checkpoint — Sprite Atlas specification

- Added `docs/heroes/SPRITE_ATLAS_SPEC.md` and committed the 2.5D asset contract.
- Defined provisional 256×256 frame size with 192×192 and 320×320 comparison variants; final size remains performance-gated.
- Defined consistent orthographic camera, transparent RGBA frames, normalized ground pivot, 8-direction naming, animation loop policy, and one-shot `projectile_release` event.
- Defined atlas/manifest JSON contract and asset acceptance checks, including alpha, cropping, pivot stability, frame order, memory footprint, and light/dark preview.
- Prototype scope is intentionally small: one diagonal direction, idle/walk only, 6–8 sample frames per animation, and three resolution variants.
- No 3D source model, final production frames, runtime atlas loader, game engine, or Android test has been created yet. The generated concept sheet is not a production sprite atlas and is not being treated as one.
- Next: inspect the legacy repository for reusable hero source/rendering materials and inspect available tooling before committing to a renderer workflow. Then make the engine decision based on a small measurable prototype.


## 11. تدقيق إضافي — خط إنتاج الرامي القديم

- فُحصت ملفات `pubspec.yaml`, `hero_catalog.dart`, `game_screen.dart`, `sprite_sheet_frame.dart`, `combat_painters.dart`, `main.dart`, واختبار كتالوج الأبطال، بالإضافة إلى لوحات SVG الأربع.
- العارض القديم يقتطع SVG أفقياً فقط باستخدام Flutter widgets؛ لا يقرأ manifest ولا يدير pivot أو 8 اتجاهات أو animation events.
- حلقة إطلاق الأسهم في شاشة اللعب القديمة منفصلة عن إطارات الهجوم وتعمل بمؤقت دوري؛ لا ننقلها لأن Archer FM يتطلب حدث إطلاق واحداً متزامناً مع حركة الهجوم.
- لم نجد في الملفات المفحوصة نموذج 3D أو Blender أو خط تصيير 3D أو مولّد Atlas. الأصول القديمة مرجع 2D فقط.
- أضيف التقرير التفصيلي: `docs/heroes/LEGACY_RANGER_PIPELINE_AUDIT.md`.
- القرار العملي: نبني لاحقاً فاحص PNG/manifest مستقل عن المحرك، ونؤجل عارض اللعبة حتى اختيار المحرك. إنتاج إطارات 2.5D النهائية يتطلب نموذج 3D وأداة تصيير فعلية؛ لا نعامل concept sheet كأصل تشغيل.


## 12. أول أدوات ضمان الجودة للرامي

- أضيف `tools/validate_hero_assets.py`: فاحص مستقل عن محرك اللعبة، يعتمد Python standard library فقط.
- يفحص إصدار manifest، هوية البطل، أبعاد الإطار، pivot، وجود ملفات PNG وقراءة أبعادها من IHDR، تطابق أبعاد metadata، حدود مستطيلات الإطارات، منع تدوير الإطارات، مراجع frames داخل الأنيميشن، أزمنة الإطارات، وصحة مواقع animation events.
- أضيف `tools/tests/test_validate_hero_assets.py` مع اختبار manifest صحيح واختبار مرجع إطار مفقود.
- هذه أداة تحقق بنيوي للأصول وليست بديلاً عن معاينة الحركة أو اختبار الأداء أو محاكي Android.
- لم تُشغّل الاختبارات بعد داخل بيئة checkout للمستودع؛ تمت إضافة الكود والاختبارات إلى GitHub فقط. يجب تشغيلها في بيئة تطوير فعلية عند تجهيز checkout.
- لا توجد بعد ملفات atlas أو PNG إنتاجية للرامي كي تمر عبر الفاحص؛ هذه الخطوة تجهز بوابة الجودة قبل وصول الأصول.


## 13. قرار أسلوب التنفيذ — النسخة الكاملة فقط

بناءً على توجيه المستخدم بتاريخ 2026-11-14، لا نعتمد أسلوب النماذج التجريبية الجزئية التي ننتجها ثم نستبدلها لاحقاً. نستثمر الوقت مباشرة في مواصفات وتنفيذ النسخة الإنتاجية الكاملة للرامي.

- المطلوب من الرامي: نموذج 3D نهائي قابل لإعادة الإنتاج، Rig كامل، الاتجاهات الثمانية، والحركات الأربع كاملة (idle / walk / attack / death)، مع حدث إطلاق السهم والـmanifest والأطالس والملفات المصدرية.
- لا نسلّم اتجاهًا واحدًا أو حركتين مؤقتتين كمرحلة إنجاز، ولا نعتمد أصولاً مؤقتة على أنها النسخة النهائية.
- تُحسم المواصفات الفنية والميزانية المستهدفة للذاكرة والأداء قبل التصدير الكامل، وتُفحص الحزمة النهائية كاملة.
- بعد اكتمال الأصول، نربطها بمحرك اللعبة، وننفذ اختبارات التكامل والقتال، ثم تشغيل Android Emulator وإصلاح الأخطاء وإعادة الاختبار.
- أداة فحص manifest التي أضيفت سابقاً تبقى أداة جودة نهائية قابلة للاستخدام، وليست دعوة لإنتاج نموذج تجريبي.
- لا يزال إنتاج النموذج ثلاثي الأبعاد النهائي غير منفذ؛ لا نعتبر الرامي مكتملاً حتى توجد الملفات الفعلية وتنجح بوابات القبول أعلاه.


## 14. بدء التنفيذ الإنتاجي الكامل للرامي — 2026-11-14

- أضيف خط تصيير Blender كامل الاتجاهات والحالات: `tools/blender/render_hero.py`.
- أضيف إعداد إنتاج `assets/heroes/ranger/source/render_config.json` يعرّف الاتجاهات الثمانية والحركات الأربع ومعدلات الإطارات ومواقع أحداث إطلاق السهم.
- أضيف دليل `docs/heroes/RANGER_ASSET_PIPELINE.md` وفيه جرد إعادة الاستخدام من المشروع القديم وعقد مشهد المصدر وبوابات قبول الإصدار.
- إعادة الاستخدام المعتمدة: الاحتفاظ بأصول SVG الأربعة القديمة كمراجع/احتياط؛ عدم نقل عارض القص القديم أو منطق إطلاق السهم بالمؤقت لأنه لا يطابق بنية 2.5D والأحداث المتفق عليها.
- التدقيق السابق لم يعثر على نموذج 3D أو Rig أو مشروع Blender قديم جاهز؛ لذلك لا يوجد مصدر شخصية ثلاثي الأبعاد جاهز لنقله.
- أداة التصيير تتطلب ملف المصدر الحقيقي `ranger_source.blend` مع Rig وأربع Actions مسماة. لم يُنشأ هذا الملف بعد، ولم تُنتج إطارات PNG نهائية أو أطالس؛ لا نعلن إنجاز الرسم قبل وجودها.
- Blender مناسب كأداة إنتاج لأنه يدعم إخراج PNG وملفات glTF مع الحركة، وفق وثائقه الرسمية.
- الخطوة التنفيذية التالية: تأمين/إنشاء مصدر Ranger ثلاثي الأبعاد أصلي متوافق مع الهوية المعتمدة، ثم تشغيل التصيير الكامل ومراجعة الناتج، لا تصدير عينات مؤقتة.


## 15. بناء مصدر الرامي — مصدر Blender قابل للتحرير

- أضيف `tools/blender/build_ranger_source.py`: مولّد مصدر Blender أصلي يبني مجسم Chibi مقسماً إلى أجزاء قابلة للتحرير، خامات خضراء/ذهبية/جلدية، شعر فضي وعيون زرقاء، قوس زمردي وجعبة، Armature باسم `Ranger_Rig`، وأربع Actions مسماة، وكاميرا Orthographic وإعدادات شفافية.
- أضيفت تعليمات تشغيل المصدر إلى `docs/heroes/RANGER_ASSET_PIPELINE.md`.
- صُحح مسار جذر المستودع في `tools/blender/render_hero.py` حتى يقرأ إعدادات الإنتاج من المسار الصحيح.
- قيد بيئة التنفيذ الحالية: أمر Blender غير مثبت، لذلك لم يمكن تشغيل المولّد هنا ولم ينتج ملف `.blend` ثنائي أو إطارات PNG بعد. الموجود على GitHub هو مصدر البناء القابل لإعادة الإنتاج، وليس ادعاءً بأن ملف Blender قد تم توليده أو فحصه بصرياً.
- يجب تشغيل المولّد في Blender فعلياً، ثم فتح `ranger_source.blend` وفحص شكل المجسم، تموضع الأجزاء على العظام، ومدى صلاحية الحركات الأربع قبل تصيير الحزمة الكاملة.


## 16. استكمال خط إنتاج المصدر والأطالس

- عُدّل `render_hero.py` ليحوّل إطار إطلاق السهم من توقيت مشهد Blender إلى فهرس الإطار الأقرب ضمن الإطارات المصدّرة؛ هذا يطابق عقد manifest الذي يتطلب فهرساً ضمن قائمة frames.
- أضيف `tools/blender/pack_hero_atlases.py`: يجمع صور كل حركة/اتجاه في أطلس PNG مستقل مع TexturePacker-style JSON metadata، ويحدّث manifest بمراجع الأطالس.
- خُفّض استهلاك الذاكرة في جامع الأطالس باستخدام float arrays بدلاً من قوائم Python كبيرة.
- وُثّق تسلسل البناء والتصيير والتجميع والتحقق.
- لم يتم تشغيل Blender أو تصيير PNG في هذه البيئة؛ لذلك لا توجد نتيجة اختبار تشغيل أو تحقق فعلي حتى الآن. يبقى فتح ملف المشهد وفحص الـrig والحركات بصرياً خطوة قبول إلزامية.


## 17. بوابة التحقق الآلي لمصدر الرامي

- أضيف `tools/blender/validate_ranger_source.py` للتحقق داخل Blender من وجود العظام العشرة المطلوبة، الكاميرا، الشفافية، أجزاء المجسم المرتبطة بالعظام، الخامات الأساسية، ومفاتيح الحركات الأربع.
- أضيف GitHub Actions workflow باسم `Ranger Blender Asset Pipeline` يقوم ببناء ملف Blender، وفحص المشهد، وتصييـر الاتجاهات والحركات كاملة، وتجميع الأطالس، وتشغيل مدقق manifest، ثم رفع الناتج كـ artifact.
- تم إصلاح تموضع أجزاء المجسم عند ربطها بالعظام بحساب inverse لمصفوفة العظمة كاملة، كما أصبحت الكاميرا أمامية تقريباً لتكون مرجع الاتجاهات الثمانية أكثر اتساقاً.
- تم رصد تشغيل GitHub Actions رقم 1 على commit `587f5175ab8a53736e62e894bff8941a454e24ab` وحالته عند آخر فحص كانت `queued`. لا نعلن نجاح البناء أو التصيير قبل ظهور النتيجة النهائية ومراجعة سجل الوظيفة والـartifact.


## 18. Ranger مرجع الجودة — 2026-11-15

- أُعيد بناء مصدر Ranger بمحتواه الصحيح بعد اكتشاف أن ملفات المصدر الأربعة كانت تحتوي محتوى Storm بسبب `active_hero.txt`. اكتشاف حرج: بناء أي بطل يكتب في مسار Ranger الثابت أيضاً، لذلك يجب تعيين المُعلّم قبل كل بناء.
- تحسينات المطابقة على `build_ranger_source.py`: بشرة أدفأ، أذنان أصغر ومخفيّتان خلف الشعر، حواجب أنحف، عينان مع بياض أوضح، إمالة أشواك التاج للخلف، تقليل قرون الشعر الجانبية وهالة القوس، وتقوية توهج الطاقة.
- فحص المشهد داخل Blender: `HERO_SOURCE_OK` — 191 جزء شبكي، 30 عظمة، 8 حركات (idle/walk/run/attack/skill/dodge/hit/death)، 26 خاماً.
- أداة معاينة جديدة `tools/blender/preview_hero.py` تنتج أربع زوايا (أمام/ثلاثة أرباع/جانب/خلف) في جلسة Blender واحدة بنفس إسقاط الإنتاج؛ المعاينات المعتمدة في `docs/heroes/ranger_review/`.
- الرندر الإنتاجي الكامل (8 حالات × 8 اتجاهات = 496 إطاراً، 192px) قيد التنفيذ؛ الأطالس والـ manifest والتحقق النهائي تأتي بعد اكتماله.
- Flame/Shadow/Storm: البناء موجود في شجرة العمل لكنه لم يُرفَع بعد؛ بانتظار مراجعة المستخدم لـ Ranger واعتماده.

## 19. Ranger داخل اللعبة — بناء طبقة القتال (2026-11-17)

- بُنيت طبقة لعب حقيقية من الصفر (كان المشروع عارض أنيميشن فقط): محاكاة معركة نقية بـ`GameWorld` (خطوة ثابتة 16ms)، رسم بـ`ArenaPainter`، شاشة لعب بـ`GameScreen` (جويستيك، هجوم، مراوغة، 4 أزرار قدرات مع عدّاد انتظار وقفل بالمستوى، HUD كامل)، وقائمة رئيسية في `main.dart` بحيث زر "لعب" مفعّل لـRanger (`ranger_new`) فقط حالياً.
- الضرر الحقيقي متزامن مع الأنيميشن: الأسهم تنطلق فقط على إطارات أحداث السلاح المصرّح بها في manifest الإنتاج (`projectile_release` عند الإطار 5 من الهجوم، `volley_release` عند الإطار 5 من المهارة)، فلا ضرر بلا حركة ولا حركة بلا ضرر.
- سلسلة الضربات الخمس 100/110/120/135/155% نافذة كومبو 1800ms مع منع الاحتساب المزدوج وإعادة الضبط بعد النافذة/المراوغة/الضرر؛ القدرات الأربع (وابل متعدد/سهم ثاقب/مطر السهام/اندفاع الرياح) تُفتح بالمستويات 1/10/20/30 مع حفظ التقدم في `SharedPreferences`.
- الاختبارات: حزمة كاملة 55/55 ناجحة (منطق القتال 30، تكامل الشاشة 6، التقاط بصري 1، عارض وmanifest 18). التقاط بصري بالأطالس الحقيقية بعد لحام الوجه في `/tmp/opencode/merge/captures/` وتم فحصه: الـsprite الحقيقي، القوس والسهام الخضراء، الوابل المتفرق، ومنطقة المطر كلها تُرسم وتمارس ضرراً فعلياً.
- إصلاحات أثناء التكامل: كاش الـmanifest في `BundleHeroAssetLoader`، خريطة الاتجاهات الثمانية في مساحة الشاشة (+y لأسفل)، تخطيط Stack (HUD بـPositioned وإلا كان الارتفاع 103px والأزرار خارج الشاشة)، `drainEvents` ينسخ قبل التفريغ، وstops لمتدرج الخلفية. التفاصيل الكاملة بالأرقام: `docs/game/ranger_combat.md`.
- لم يُشغّل اللعبة على جهاز حقيقي بعد (لا يوجد جهاز/محاكي متصل في هذه البيئة)؛ التجربة اليدوية على الهاتف هي خطوة الاعتماد النهائية. Flame/Shadow/Storm تبدأ بعد اعتماد Ranger.

## 20. Flame داخل اللعبة (2026-11-17)

- اعتُمد Flame (`flame`) كثاني بطل قابل للعب بأصوله الموجودة (64 حالة/64 أطلس + أحداث سلاح `melee_impact`/`inferno_burst` مصرّح بها في manifest الإنتاج) دون أي إعادة إنتاج أو تعديل للأصول.
- بنية قتال قريب المدى مستقلة تماماً عن الرامي: قطع قوسي ±66° بمدى 100 على إطار الاصطدام، حريق مستمر (DoT) 3×25% من ضربة اللهب (180%)، موجة نار أرضية متحركة (كيان `WaveState` جديد، 160% + حريق)، انفجار الجحيم نصف قطر 140 بـ220%، وهياج (وتيرة ×1.4/ضرر ×1.25/مدى ×1.2 لـ6 ثوانٍ). الكومبو الخماسي 100/110/120/135/155% بنافذة 1800ms، الأقفال 1/10/20/30، حفظ التقدم كما في Ranger.
- الواجهة صارت بلون هوية كل بطل (برتقالي 0xFFFF7A33 لـFlame) عبر `HeroKit.accentColor`: زر الهجوم، الجويستيك، أزرار القدرات، وأشرطة HUD. القائمة الرئيسية: "لعب" مفعّل لـRanger II وFlame.
- الاختبارات: الحزمة كاملة 70/70 ناجحة (7 اختبارات قتال جديدة لـFlame + اختبارا شاشة + اختبار kit + لقطات بصرية بأصول flame الحقيقية تم فحصها: القطع/الانفجار/الموجة/الحريق). تفاصيل الأرقام: `docs/game/flame_combat.md`.
- تبقى: التجربة اليدوية على جهاز (قيد البيئة نفسه)، ثم Shadow ثم Storm.

## 21. Shadow داخل اللعبة (2026-11-17)

- اعتُمد Shadow (`shadow`) كثالث بطل قابل للعب بأصوله الموجودة كاملة (64 حالة/64 أطلس + أحداث سلاح `melee_impact`/`shadow_burst` مصرّح بها في manifest الإنتاج) دون أي إعادة إنتاج أو تعديل للأصول.
- هوية النصال البنفسجية: أسرع بطل (حركة 178) بأقصر مدى (85) وأوسع قوس (±74°)؛ قدرات مختلفة ميكانيكياً: أنياب التوأم 3×80%، حجاب الظل (4 ثوانٍ مناعة كاملة + سرعة ×1.35 + رسم شفاف)، معطف السم (سمم 2×15% لكل طعنة + ضرر ×1.15 لمدة 8 ثوانٍ)، إعدام الظل (انتقال خاطف خلف أضعف عدو داخل 320 وطعنة 300% مع رد طاقة إن لم يوجد هدف).
- الحريق (Flame) والسم (Shadow) يتشاركان `_applyDoT` بمنطق تنعيم بالأقوى بدون تراكم؛ `buffMoveMult` جديد في الـkit (Ranger = 1.25 كما هو، Flame/Shadow = 1.0) و`speedBoostUntilMs` للحجاب.
- الاختبارات: الحزمة الكاملة 83/83 ناجحة + `flutter analyze` نظيف (5 اختبارات قتال لـShadow + اختبارا شاشة + اختبار kit + 4 لقطات بصرية بأصول shadow الحقيقية تم فحصها: القوس/الحجاب الشفاف/الإعدام). تفاصيل الأرقام: `docs/game/shadow_combat.md`.
- القائمة الرئيسية: "لعب" مفعّل الآن لثلاثة أبطال (Ranger II، Flame، Shadow). تبقى Storm (أصوله الرندرية مفقودة: 4 SVG فقط) ثم التجربة اليدوية على جهاز.

## 22. Storm داخل اللعبة بالمجسم الأصلي (2026-11-17)

- اعتُمد Storm (`storm`) رابع بطل قابل للعب — وهذه المرة **بالمجسم الأصلي المرفوع من
  المستخدم** `assets/heroes/storm/storm.glb` (21,599,708 بايت، موديل Tripo بلا هيكل
  عظمي ولا حركات، بنسيج basecolor مدمج). الملف الأصلي محفوظ بتلاته دون أي تعديل،
  واختبار provenance يتأكد أن حجمه 21,599,708 بايت بالضبط.
- لأن الأصل ثابت بلا رِج، رُبط المجسم الأصلي نفسه (شبكته + نسيجه) على هيكل البيت
  الموحّد (30 عظمة + 8 حركات `Storm_*` من `storm_source.blend`) عبر
  `tools/blender_rig_original_storm.py`: تطبيع إلى إطار الهيكل المقيس
  (z 0.12..3.06)، تخفيض كثافة 273,845 رأس → 29,643 رأس (~33 ألف مثلث)، وربط صلب
  (وزن 1.0) لأقرب عظمة من **عظام الجسم الأساسية 20 فقط** (بلا عظام الـoverlay
  aura/bow/cloak/quiver/root). الناتج `assets/heroes/storm/model/
  storm_animated.glb` (8.4MB): skin + JOINTS_0/
  WEIGHTS_0 + 8 كليبات + النسيج الأصلي مدمج.
- التحقق بالبيانات (قراءة Dart سليمة): مصفوفات السكن عند REST مطابقة للمصفوفة
  المحايدة تماماً (بلا تشوه)، صندوق إحاطة السكن عمودي (y 0.12..3.06) — توزيع
  الأوزان التشريحي: head 6579، thigh.R 4634، thigh.L 2723، upper_arm.R 2323...
  ولقطات `ArenaPainter` (الحقيقة المرجعية للعرض): المجسم يظهر داخل الحلبة بنسيجه
  الأصلي في idle/attack/run من الاتجاهين الجنوبي والشرقي، بنفس إعداد العرض الذي
  يجعل Flame سليماً.
- القتال: `thunder_thrust` (طعنة 160% + سلسلة 60% لأقرب جار ≤200)،
  `chain_lightning` (3 أقرب أعداء ≤180 بـ130% لكل واحد مع رسم برق متعرج `bolt`
  جديد في `ArenaPainter`)، `static_field` (توهين 8 ثوانٍ + شحنة ثانية 40% لكل
  قطع أثناء التفعيل)، `tempest_rage` (ضرر ×1.2/وتيرة ×1.3/مدى ×1.25 لـ6 ثوانٍ —
  أطول مدى قتال في اللعبة 125 وحدة). الكومبو الخماسي 100/110/120/135/155%.
- القائمة الرئيسية: "لعب" مفعّل لأربعة أبطال (Ranger II، Flame، Shadow، Storm) —
  `playableIds` تتضمن `storm` و`stormKit.playable = true`.
- الاختبارات: **106/106 ناجحة** + `flutter analyze` نظيف (توزيع القدرات، قفل
  المستويات 1/10/20/30، ضرر السلسلة والبرق بالأرقام الدقيقة، provenance الأصل،
  لقطات 74/75/76 لـFlame/Shadow/Storm داخل الحلبة).
- تبقى: التجربة اليدوية على جهاز حقيقي (قيد البيئة نفسها).

## 23. تدقيق وتثبيت ضربات الـSpecial الـ16 (2026-11-17)

- تدقيق من الكود (لا من التقارير): التعريفات الـ16 في `lib/game/combat/hero_kit.dart`،
  والتنفيذ الفعلي في `GameWorld` لكل قدرة (ضرر/مدى/أهداف/DoT/buff/cooldown/طاقة)،
  والربط بالأنيميشن عبر أحداث المانيفست في `GameScreen._handleCombatEvent`.
- قفل المستويات 1/10/20/30 مطبّق في `useAbility` لكل الأبطال الأربعة، ومثبت
  باختبارات رفض قبل الفتح وقبول بعده.
- إصلاح فجوتين بصريتين: `gale_surge` و`venom_coat` كانا بلا مؤثر لحظي — أُضيف
  `burst` بلون البطل عند التفعيل. وحُذف `DBG giant` print من
  `hero3d_painter.dart` (كان يطبع كل إطار في الإنتاج).
- اختبارات جديدة: مجموعة «special abilities stay independent of the five-hit
  combo» (4 أبطال: القدرة لا تقدّم/تُصفّر السلسلة، والهجوم العادي مرفوض أثناء
  قدرة معلّقة، والسلسلة تصل 155%) + مجموعة «ability energy and cooldown work for
  every hero» (4 أبطال بطاقة/تبريد فعليين).
- إثبات بصري داخل اللعبة: 9 لقطات جديدة عبر `ArenaPainter` الحقيقي مع ضرر محسوب
  من فرق HP فعلي (`test/special_abilities_capture_test.dart`):
  `13_piercing_shot`، `14_gale_surge`، `15_inferno_rage`، `16_twin_fangs`،
  `17_venom_coat`، `18_thunder_thrust`، `19_chain_lightning`،
  `32_static_field`، `33_tempest_rage`.
- النتيجة: **115/115 اختبار ناجح** + `flutter analyze --no-pub` نظيف.
  التفاصيل والجدول الكامل: `docs/game/special_abilities.md`.
- تبقى: التجربة اليدوية على جهاز حقيقي فقط (قيد البيئة بلا شاشة لمس/صوت).

## 24. إصلاح أنيميشن الأبطال الجذري (2026-11-17)

- **العَرَض**: كل كليبات Flame/Shadow/Storm كانت تُشحن كوضعية واحدة ثابتة
  (كل قناة بقيمة واحدة، maxDelta = 0.00000) رغم أن ملفات المصدر `.blend` تحتوي
  الحركات كاملة (Flame_Attack = 1890 مفتاحاً على 270 منحنى).
- **السبب 1 (التصدير)**: `tools/blender_export_glb.py` كان يفرض
  `armature.data.pose_position = 'REST'` أثناء التصدير، فلا يعاين المُصدِّر
  الأكشنات ويعيد وضعية الراحة في كل عينة.
  الإصلاح: `POSE` + إزالة الأكشن النشط + تصفير loc/scale والـrotation حسب
  `rotation_mode` الحالي. (تغيير `rotation_mode` إلى QUATERNION جُرِّب وأفسد
  الحركة لأن أكشنات المصدر تحرّك منحنيات Euler.)
- **السبب 2 (وقت العينة)**: `_Track.sample` في `lib/game/render3/glb.dart` كان
  يقارن زمناً بالمللي ثانية مع مفاتيح glTF بالثواني، فيقفز الكليب لآخر مفتاح
  بعد أجزاء من الثانية. الإصلاح: `var t2 = t / 1000.0;` داخل `sample`.
  اختبار `glb_loader_test` كان يعتمد على هذا الخلل (يفترض أن 800ms = آخر
  فريم) وصُحِّح ليقيس آخر فريم من مدة الكليب الفعلية.
- **Storm**: لا يوجد `storm_source.blend` (كان أثر بناء مؤقت)، وأداة
  `tools/copy_glb_animations.py` تنقل حركات Flame إلى هيكل Storm المطابق
  بالاسم (لا بالindex)، وتستبدل الكليبات المكررة بنفس الاسم. بصمة الشبكة/
  النسيج/الجلد قبل/بعد متطابقة، و`assets/heroes/storm/storm.glb` الأصلي
  (21,599,708 بايت) لم يُمس.
- **النتيجة المقاسة (قنوات متحركة / 90)**: Flame Attack 14، Run 16، Skill 17،
  Death 26 · Shadow Attack 12، Run 16، Skill 19، Death 26 · Storm Attack 14،
  Run 16، Skill 17، Death 26 · Ranger جميع الكليبات متحركة (63 قناة).
- **حارس جديد**: `test/hero_animation_test.dart` يفحص 8 كليبات × 4 أبطال
  ويُفشل أي كليب مجمَّد (مقارنة `Poser.skin` بين t=0 و50% من المدة).
- **التحقق النهائي**: `flutter analyze --no-pub` نظيف و**116/116 اختبار ناجح**،
  وأُعيد توليد لقطات `ArenaPainter` (71–76 + القدرات 13–19/32/33) بعد الإصلاح.

## 25. نظام الوحوش والجيش (2026-11-17)

- **النطاق المنجز**: الأنواع الأربعة المعتمدة فقط (`runner` العدّاء، `tank`
  المدرّع، `stalker` المتربص، `ranged` الرامي) — لا أنواع جديدة ولا بوس.
  الكتالوج والإحصاءات في `lib/game/monsters/monster_models.dart`، والمحاكاة في
  `GameWorld` (جيش اللاعب + موجات الأعداء)، والرسم في `ArenaPainter`.
- **الجيش**: يبدأ كل شوط بـ20 وحشاً مجاناً بتوزيع متوازن (6 عدّاء، 5 مدرّع،
  5 متربص، 4 رامي) حول البطل، مع سقف أداء 40 وحشاً حياً. الشراء أثناء المعركة
  بالموارد: عدّاء 30، متربص 40، رامي 45، مدرّع 55. الوحش المشترى يظهر بجوار
  البطل (بديل مؤقت لبوابة القلعة غير الموجودة بعد). دخل سلبي 2 موارد كل 1.5
  ثانية، ومكافأة موارد/جوهر عند كل قتل.
- **الموت الدائم**: لا إحياء للوحوش. الميت يُزال من الجيش نهائياً ويُترك جثة
  تتلاشى في 700ms، ويُطلق `ArmyMonsterLostEvent` لتظهر رسالة HUD. الاستبدال
  يكون بالشراء فقط.
- **القتال والذكاء الاصطناعي**: كل وحش يستهدف أقرب عدو داخل مداه
  (جيش 340 / أعداء 320)، ويتحرك كمجموعة بفصل مكاني (لا تتراكم الأجساد)،
  ويعود إلى تشكيل دائري حول البطل عند غياب الأعداء. سلوكيات مميزة: العدّاء
  يندفع ×2.15 كل 2.4 ثانية، المتربص يناور جانبياً، الرامي يحفظ مسافة ويرمي
  مقذوفات صديقة، والمدرّع بطيء وصلب. الأعداء يستهدفون الجيش أولاً ثم البطل.
  المقذوفات أصبحت `hostile` صريحة: مقذوف العدو يصيب الوحوش ثم البطل، ومقذوف
  الجيش لا يصيب إلا الأعداء.
- **الحركات الطبيعية**: هيكل إجرائي بأرجل وأذرع تتأرجح من `walkPhase` المدفوع
  بالمسافة المقطوعة فعلاً (`sin` لكل قدم بإزاحة π)، مع ركض/وقوف/هجوم
  (اندفاع 320ms)/موت. الهيئة مختلفة لكل نوع: قرون للمدرّع، وشاح وأذنان
  للعدّاء، عباءة وخفّ للمتربص، عصا نار للرامي. شريط HP دائم، حلقة لون الفريق،
  اهتزاز وميض عند الإصابة، ومؤشر حريق.
- **الترقية حتى 40**: ترقية دائمة لكل نوع منفصلة، تُدفع بالجوهر (20 ثم
  +12 لكل مستوى)، تُحفظ مع تقدم البطل في `SharedPreferences`
  (`armyLevels` + `essence`). التدرج: HP ×(1+0.065×(L−1))،
  ضرر ×(1+0.05×(L−1))، سرعة ×(1+0.012×(L−1))، وتكلفة/خبرة القتل ترتفع مع
  المستوى. الوحوش المشتراة بعد الترقية تولد بالمستوى الجديد.
- **الواجهة**: HUD يعرض عدد الجيش والموارد والجوهر، وأربعة أزرار شراء بعدّاد
  النوع وسعره، وزر "ترقية الوحوش" يفتح حواراً يعرض المستوى والإحصاءات
  والتكلفة لكل نوع.
- **الاختبارات**: `test/monster_system_test.dart` (21 اختباراً: الكتالوج،
  التدرج حتى 40، توزيع الجيش الـ20، الشراء والحد الأقصى، الدخل، الموت الدائم
  والجثث، إنفاق سهم العدو على أول جسد يصيبه، دورة المشي والوقوف، الفصل،
  الاستهداف، المقذوفات الصديقة، الاندفاع، الموجات، المكافآت) +
  `test/monster_capture_test.dart` (لقطتان بصريتان `20_monster_lineup`
  و`21_monster_gait` لكل الأنواع والفريقين والجثة).
  الحزمة الكاملة أصبحت **138/138 ناجحة**، و`flutter analyze --no-pub`
  انتهى بـ**No issues found** (exit 0) بعد تنظيف الملاحظات القديمة الثلاث.
- **إصلاحات أثناء الاختبار**: `EnemyState.speed` صار قابلاً للتعديل لاختبارات
  الاندفاع؛ إضافة فصل إجباري عند ولادة وحش جديد لمنع تراكب الجيش؛ رفع تبريد
  رامي الأعداء إلى 2400ms حتى لا يطلق طلقة زائدة تُفسد اختبار لقطة الرامي؛
  إنهاء سهم العدو عند أول وحش يصيبه حتى لا يخترق صف الجيش.
- **مراجعة الأبطال الأربعة بعد الوحوش**: لم تتغير مجسمات/أطالس/حركات الأبطال؛
  `ArenaPainter` يرسم الوحوش قبل البطل فقط. اختبارات اللقطات الحقيقية
  (`game_capture_test`, `hero3d_game_capture_test`,
  `special_abilities_capture_test`) نجحت كلها، واختبار الأصالة يؤكد أن
  `assets/heroes/storm/storm.glb` ما زال 21,599,708 بايت دون تغيير.
- **حدود معروفة**: لا قلاع/كريستالات/مناجم/أونلاين في المشروع بعد، لذلك
  استهداف الوحوش يقتصر حالياً على الأبطال والوحوش، والشراء يتم بجوار البطل
  بدل بوابة القلعة. أصول الوحوش القديمة غير متاحة، والبديل إجرائي ومطابق
  للسلوك المطلوب؛ استبداله لاحقاً يمس `ArenaPainter` فقط.
- **التجربة على جهاز**: لا يوجد جهاز/شاشة في بيئة العمل؛ التثبيت الفعلي
  واللعب اليدوي هما خطوة الاعتماد النهائية.

## 26. الخريطة والعالم (2026-11-18)

- **النطاق المنجز**: خريطة واحدة كبيرة لكل شوط، حجمها عشوائي بين 1920–2400 ×
  1080–1440 وحدة (نافذة الكاميرا 960×540، أي 4–9 أضعاف المساحة المرئية).
  كل شوط يعيد توليد الحجم ومواقع القلاع والمناجم والبيومات والنهر والجسور
  والعوائق والموارد من بذرة الشوط نفسها، لذا النتيجة حتمية لكل بذرة وقابلة
  للاختبار. الملفات: `lib/game/world/arena_map.dart`,
  `lib/game/world/fog_of_war.dart`, `lib/game/minimap.dart`، والدمج في
  `lib/game/world/game_world.dart` و`lib/game/arena_painter.dart`، مع الخريطة
  المصغرة في HUD داخل `lib/game/game_screen.dart`.
- **القلاع**: أربعة مواقع عشوائية متباعدة (≥560 وحدة) داخل هوامش الخريطة،
  بنفس التصميم، وخالية من الماء والعوائق. البطل يبدأ بجوار قلعه (الموقع 0).
  بناء القلاع والكريستالات نفسه لم يبدأ بعد؛ الخريطة تحجز المواقع فقط.
- **البيومات والعوائق**: أربع مناطق (غابة، صحراء، ثلج، بركاني) بحدود دائرية
  متداخلة، و52 شجرة و20 صخرة غير قابلة للتدمير تمنع المرور وتُزيح الحركة
  جانبياً (انزلاق) بدل الالتصاق. لا منطقة تمنح مكافأة قتالية.
- **الأنهار والجسور والماء**: نهر متعرّج بعرض 80–114 وحدة يعبر الخريطة،
  يُعاد رسمه حتى يبتعد عن ساحات القلاع، مع جسرين جافّين. الماء يبطئ الحركة
  ×0.6 للبطل والوحوش، والجسر سرعته طبيعية.
- **الموارد والصناديق**: 6 مجموعات موارد و2 صندوق على أرض جافة واضحة، بحدود
  «قيم موازنة مبدئية» غير نهائية مثل بقية أرقام §5.
- **الضباب والرؤية**: شبكة 64 وحدة تبدأ مخفية وتُكشف حول البطل (نصف قطر
  260) وتبقى مكشوفة بعدها. الأعداء لا يُرسمون إلا داخل 420 وحدة من البطل
  (`isEnemyVisible`/`visibleEnemies`). الضباب يُرسم داخل نافذة الكاميرا فقط
  حتى لا تُمسح الخريطة كاملة كل إطار.
- **الكاميرا**: تتبع البطل وتُقيَّد بحدود الخريطة، والرسم يقتصر على ما يراه
  اللاعب. كل حركة/توليد/إنعاش صار مقيّداً بحدود الخريطة المولَّدة بدل حدود
  النافذة الثابتة السابقة، مع بطء الماء وتصادم العوائق.
- **الخريطة المصغرة**: مستطيل أسفل وسط HUD يعرض التضاريس المكتشفة والأنهار
  والقلاع (قلع البطل مميزة بلون ذهبي) والمناجم بأحجامها الثلاثة، والبطل.
  القلاع والمناجم تبقى ظاهرة على الخريطة المصغرة مهما بعدت المسافة
  (`minimapMarkers`). تمثيل الكريستالات مؤجل لخطوة القلاع لأنها غير موجودة بعد.
- **فحص المشروع القديم**: `Archero_fm` لا يضم أي نظام خرائط أو مناجم أو قلاع؛
  الموجود فقط `lib/world_theme.dart` (ألوان 6 عوالم) و`lib/player_movement.dart`
  (حركة داخل شاشة ثابتة). لا ملفات قابلة لإعادة الاستخدام، فبُنيت الخريطة
  من الصفر؛ لم يُنقل أي كود.
- **الاختبارات**: `test/arena_map_test.dart` = 19 اختباراً (الحجم والنطاق،
  4 قلاع، 8 مناجم 3/3/2، النهر والجسران، 4 بيومات، الأشجار/الصخور، الموارد
  والصناديق، خلاء ساحات القلاع، بطء الماء، الانزلاق والحدود، الضباب الدائم،
  حتمية البذرة، كشف الضباب أثناء المشي، رؤية الأعداء بالمسافة، علامات الخريطة
  المصغرة، ورسم الودجت). أُضيف `test/map_capture_test.dart` لتوليد لقطات
  `30_map_world.png` و`31_map_fog.png` و`32_map_minimap.png` في
  `/tmp/opencode/merge/captures`. الحزمة الكاملة **159/159 ناجحة**،
  و`flutter analyze --no-pub` = **No issues found**.
- **تعديل اختبار قديم واحد**: اختبار العصا `joystick input moves the player
  and clamps to the arena` كان يفترض سقف 540−28 (حد النافذة القديمة). صار
  يتحقق من حدود الخريطة المولَّدة وخلوّ الموضع من العوائق، لأن النافذة لم تعد
  حدود العالم.
- **قيم موازنة مبدئية غير نهائية**: ماء 0.6، ضباب 260، رؤية عدو 420، أعداد
  الأشجار/الصخور/الموارد/الصناديق، مسافات القلاع والمناجم. موثّقة هنا كي
  تُراجع مع بقية أرقام §5 عند الموازنة النهائية.
- **حدود معروفة**: لا قلاع/كريستالات/مناجم كسلوك بعد (التقاط، إنتاج، تدمير)،
  ولا اقتصاد موارد. الخريطة المصغرة لا ترسم كريستالات حتى تُبنى. لا جهاز
  أندرويد في البيئة، لذا اختبار اللمس على جهاز فعلي يبقى خطوة الاعتماد.

## 27. المناجم والموارد والاقتصاد (2026-11-18)

- **فحص Archero_fm**: لا يوجد نظام مناجم أو سيطرة أو إنتاج في المشروع القديم.
  الموجود فقط `lib/coin_pickup_resolver.dart` مع اختباره: دالة نقية تتحقق من
  قرب اللاعب من العملة (`pickupRadius = 34`)، و`assets/coin.svg` للرسم. لا
  بنية قابلة للنقل، لكن قاعدة «الالتقاط باللمس» أُعيد استخدامها بنفس نصف
  القطر 34 داخل `MineController.collectAt` دون نسخ الملف. بقية النظام جديد.
- **الملفات**: `lib/game/world/mine_system.dart` (جديد: `MineState`,
  `MineController`, `ResourcePickup`)، والدمج في
  `lib/game/world/game_world.dart` (تحديث، التقاط، أحداث، حماية السعة)،
  والرسم في `lib/game/arena_painter.dart`، وتمثيل الملكية على
  `lib/game/minimap.dart`، ولوحة المناجم/السيطرة في `lib/game/game_screen.dart`.
- **المناجم الثمانية**: مواقعها وأحجامها (3 صغيرة، 3 متوسطة، 2 كبيرة) تأتي من
  مولّد الخريطة، وتبدأ محايدة. لا صحة لها ولا تُدمَّر، ويمكن للاعب جمع أكثر من
  منجم في الوقت نفسه. لكل حجم حلقة لونية ونقاط حجم ومخزون خام ذهبي.
- **السيطرة 10 ثوانٍ (مؤكد)**: البقاء داخل دائرة المنجم 10 ثوانٍ متصلة يسجّل
  الملكية. الخروج يعيد التقدّم إلى الصفر التزاماً بشرط «البقاء داخل المنطقة».
  وجود أكثر من لاعب داخل المنطقة يوقف التقدّم مؤقتاً (كما هو منصوص) ولا يصفّره،
  ويستأنف عند بقاء لاعب واحد. اللاعب المالك لا يحتاج سيطرة داخل منجمه.
- **أخذ منجم مملوك**: خصم يدخل منجم اللاعب ويُكمل 10 ثوانٍ ليصبح المالك؛ لا
  حاجة لتدمير شيء. المنطق مبني على خريطة `playerId → موقع`، لذا يعمل مباشرة
  لأربعة لاعبين عند وصول الأونلاين؛ حالياً لا يوجد إلا اللاعب المحلي.
- **الإنتاج**: كل منجم مملوك يُنتج تلقائياً أثناء غياب مالكه (وإن كان بعيداً)
  كل 4/3/2 ثوانٍ للحجم صغير/متوسط/كبير، بمقدار 12/20/32. المحايد أو المملوك
  لخصم لا ينتج للاعب. الأكوام تُوضع على حافة المنجم في أرض جافة خالية من
  العوائق. هذه **قيم موازنة مبدئية** غير نهائية.
- **الالتقاط الفيزيائي**: لا تُضاف الموارد تلقائياً أبداً؛ يجب أن يمشي البطل
  فوق الكومة (نصف قطر 34 كما في المشروع القديم). تبقى الكومة غير الملتقطة
  على الأرض 24 ثانية (قيمة موازنة مبدئية) ثم تتلاشى.
- **السعة والعملة**: العملة نفسها `GameWorld.resources` المستخدمة في شراء
  الوحوش. السعة الابتدائية المؤكدة 500، والالتقاط يتوقف عند امتلائها وتُترك
  الكومة على الأرض حتى يُصرف شيء. ترقية السعة الدائمة مؤجلة لخطوة التطوير.
- **الموارد الأرضية والصناديق**: مجموعات الموارد الست المولّدة مع الخريطة صارت
  قابلة للالتقاط (30 لكل مجموعة، قيمة مبدئية) عبر نفس المسار. الصناديق تبقى
  مرئية دون فتح لأن محتوى الصناديق/الغنائم غير محدد ويخص خطوة المعدات.
- **إزالة الدخل السلبي المؤقت**: كان §25 يوثّق دخل 2 موارد/1.5 ثانية كبديل
  مؤقت «حتى وجود المناجم». أُزيل الآن لأن المناجم هي مصدر الموارد المحدد،
  وأُزيل اختباره الوحيد من `monster_system_test.dart` (اختبارات القتل والمكافآت
  باقية). البطل يبدأ بـ320 موارد كما كان، ويكسب من القتل والمناجم.
- **الواجهة**: لوحة تحت HUD تعرض «مناجم x/8»، «حمل الموارد/السعة»، وشريط
  تقدّم «سيطرة %» أثناء الوقوف داخل منجم، وعلامة «منجمك». على الخريطة المصغرة
  تظهر المناجم دائماً وبألوان الملكية: محايد ذهبي، ملك اللاعب أخضر، الخصم أحمر.
- **الاختبارات**: `test/mine_system_test.dart` = 19 اختباراً (البداية محايدة
  والأنواع 3/3/2، 10 ثوانٍ بالضبط، التصفير عند الخروج، التوقف عند تعدد
  اللاعبين، أخذ منجم مملوك، عدم تصفير المالك، التحكم بعدة مناجم، حدث السيطرة
  مرة واحدة، الإنتاج أثناء الغياب، فترات/مقادير الأحجام، المحايد لا ينتج،
  إنتاج الخصم، الالتقاط باللمس فقط، سقف السعة 500، انتهاء عمر الأكوام، موارد
  الخريطة مقابل الصناديق، بيانات HUD، ملكية الخريطة المصغرة، واستخدام العملة
  نفسها للشراء). أُضيفت لقطة `33_mines.png` (منجم مملوك + محايد قيد السيطرة +
  خصم + أكوام) إلى `test/map_capture_test.dart`، وحُدّثت لقطتا الخريطة
  المصغرة/العالم لتظهر المناجم. الحزمة الكاملة **178/178 ناجحة**،
  و`flutter analyze --no-pub` = **No issues found**.
- **قيم موازنة مبدئية غير نهائية**: فترات الإنتاج 4/3/2 ثوانٍ، مقادير
  12/20/32، عمر الكومة 24 ثانية، مقدار موارد الخريطة 30، ونصف قطر الالتقاط 34.
  تنتظر الموازنة مع بقية أرقام §5.
- **حدود معروفة**: مخزون المنجم نفسه (تجميعه قبل الإنتاج) ما زال قراراً غير
  محسوم في §5، لذا الإنتاج يُنتج أكواماً مباشرة بلا سقف تخزين. السعة 500 تحدّ
  الملتقط من الأكوام فقط؛ مكافآت القتل القديمة قد تتجاوزها حتى تُحدد قواعد
  الإيداع في القلعة. افتح الصناديق والكريستالات مؤجلان للخطوتين التاليتين.
  لا يوجد لاعبون أونلاين بعد، لذا لا خصم بشري يستولي على منجم في اللعب الحالي.

## 28. القلاع والكريستالات (2026-11-18)

- **النطاق المنجز**: أربع قلاع (قلعة اللاعب + 3 خصوم) في مواقع الخريطة
  الأربعة، لكل قلعة **7 كريستالات** بقيم الصحة المؤكدة بالترتيب:
  500، 700، 900، 1200، 1500، 1800، 2200. **4 كريستالات مكشوفة** خارج حلقة
  الجدران و**3 داخل الجدران**. الملف الجديد
  `lib/game/world/castle_system.dart`، والدمج في
  `lib/game/world/game_world.dart`، والرسم في `lib/game/arena_painter.dart`،
  والخريطة المصغرة في `lib/game/minimap.dart`، والواجهة في
  `lib/game/game_screen.dart`.
- **تدمير مباشر بأي ترتيب**: لا بوابات إلزامية ولا ترتيب. يمكن ضرب أي
  كريستال — مكشوفاً أو داخل الجدران — أولاً. التدمير يعمل من:
  السهم العادي (مع الاستهداف التلقائي للكريستالات)، الضربة القريبة،
  مناطق القدرات، وموجات النار. يُسجّل `CrystalDestroyedEvent` عند سقوط كل
  كريستال.
- **سقوط القلعة**: عند تدمير الكريستالات السبعة تسقط القلعة وتختفي من
  العالم تماماً (لا رسم ولا خريطة مصغرة)، ويبقى اللاعب في المباراة.
  يُطلق `CastleFellEvent` مرة واحدة. القلاع الثلاث الأخرى تبقى قائمة.
- **إعادة البناء**: في **إقليم اللاعب** فقط، وهو حالياً دائرة نصف قطرها
  320 حول قلعته (قرار مؤقت لأن النص لا يحدد شكل الإقليم). المكان يجب أن يكون
  أرضاً جافة خالية من الأشجار/الصخور والمناجم والكريستالات الحية. البناء فوري
  بعد الدفع وأثناء القتال، ويُعاد استخدام **نفس قيمة HP الأصلية** للكريستال.
  الكريستال المعاد بناؤه يمكن تدميره وإعادة بنائه مرة أخرى بلا حد.
- **الحد الأقصى والتكلفة**: اعتُمد تفسير «7 كريستالات متزامنة» (وهو الحد
  الأقصى المنصوص) بدل «7 مواضع كلية». تكلفة إعادة البناء تصاعدية مؤقتة:
  120 + 60 × عدد مرات إعادة البناء السابقة. كل إعادة بناء تنتج
  `CrystalRebuiltEvent` بالتكلفة والفتحة.
- **عودة القلعة**: طُبّقت القاعدة المقترحة في النص: «القلعة الجديدة تعود مع
  أول كريستال معاد بنائه». أول إعادة بناء بعد السقوط تُعيد القلعة إلى الوجود
  بكريستال واحد، ثم تُكمل الكريستالات الباقية. بناء القلعة ككيان منفصل
  وتكلفته ما زالا قراراً غير محسوم في §5.
- **الواجهة**: جدران حجرية بأربعة أقواس وأربع بوابات (24° لكل بوابة)، ساحة
  وحصن وراية بلون الملكية، كريستالات ماسية مع توهج وأشرطة HP عند التلف،
  وأثر ظل. على الخريطة المصغرة تظهر كريستالات كل قلعة قائمة بلون الملكية
  (أخضر للاعب، أحمر للخصم) وتبقى ظاهرة مهما بعدت. لوحة «قلعتك x/7» مع زر
  «كريستال بـ…»؛ الضغط عليه يفعّل وضع اختيار المكان، واللمس داخل الإقليم
  يبني الكريستال فوراً. تُعرض رسائل الرفض: موارد غير كافية، الحد الأقصى،
  خارج الإقليم، أو مكان غير خالٍ. تحويل اللمس إلى إحداثيات العالم عبر
  `arenaToWorld` المشتركة مع الكاميرا.
- **فحص Archero_fm**: لا يوجد نظام قلاع أو كريستالات قابلة للتدمير أو إعادة
  بناء في المشروع القديم. الموجود `assets/wall.svg` (جدار حجري ثابت 64×64)
  ورسم جدران حجرية بيئية داخل `lib/combat_painters.dart`، وكريستال ضمن رسم
  سهم بعيد (تأثير بصري وليس كريستال قلعة). لا منطق صحة/ملكية/إعادة بناء،
  لذلك بُني النظام جديداً بالكامل ولم يُنقل أي كود.
- **الاختبارات**: `test/castle_system_test.dart` = 18 اختباراً: 4 قلاع و7
  كريستالات وقيم HP، 4 مكشوفة/3 داخل الجدران، تدمير مباشر لأي كريستال،
  السهم والضربة القريبة، سقوط القلعة واختفاؤها وبقاء اللاعب، رفض إعادة
  البناء عند الحد الأقصى/الموارد/خارج الإقليم/المكان المشغول، البناء الفوري
  والدفع ونفس HP، تصاعد التكلفة، إعادة تدمير الكريستال المعاد بناؤه وإعادة
  بنائه، عودة القلعة بأول كريستال، بيانات الخريطة المصغرة واختفاء القلعة
  الساقطة منها، وتحويل لمس الشاشة إلى إحداثيات العالم. أُضيفت لقطة
  `34_castles.png` إلى `test/map_capture_test.dart` (قلعة اللاعب بجدرانها
  وكريستالاتها المتضررة وقلعة خصم ساقطة). الحزمة الكاملة **197/197 ناجحة**،
  و`flutter analyze --no-pub` = **No issues found**.
- **قيم/قرارات مؤقتة غير نهائية**: تفسير «7 متزامنة»، منحنى التكلفة
  120+60×n، إقليم دائري نصف قطره 320، الجدران تُرسم ولا تمنع الحركة (النص لا
  يذكر منعها)، وعدم وجود تكلفة/قواعد منفصلة لبناء القلعة نفسها. كلها موثقة
  هنا وتنتظر قراراً في §5.
- **حدود معروفة**: لا يوجد لاعبون أونلاين أو خصوم بشريون بعد، لذا كريستالات
  الخصوم أهداف ثابتة لا تدافع عن نفسها ولا يعيد خصم بناء كريستالاته. مكافأة
  الجوهر عند تدمير كريستالات الخصم صارت تُجمع ضمن أرباح المباراة وتُصرف بعدها
  (انظر §29). بناء القلعة المنفصل ما زال قراراً غير محسوم. لا جهاز أندرويد في
  البيئة، لذا اختبار اللمس الفعلي لوضع اختيار مكان الكريستال يبقى خطوة اعتماد
  على الجهاز.

## 29. التطوير الدائم والمعدات والصناديق (2026-11-18)

- **النطاق المنجز**: عملة دائمة واحدة (`essence`) منفصلة عن موارد المباراة،
  وأربع خامات مستقلة (`hero`، `monster`، `equipment`، `capacity`)؛ لا ترقية
  بمجرد العملة. الملفات الجديدة `lib/game/progress/equipment.dart`،
  `lib/game/progress/progression.dart`، و`lib/game/progress/progression_screen.dart`،
  مع توسيع `hero_progress.dart` و`game_world.dart` و`game_screen.dart` و`main.dart`.
- **الأرباح بعد المباراة**: قتل الوحوش وتدمير كريستالات الخصوم يضيفان إلى
  `pendingEssence` و`pendingMaterials` أثناء المباراة؛ `settleMatch()` (عند
  الخروج) يصبّهما في المحفظة الدائمة. الخسارة أو الانسحاب لا يُفقدان اللاعب
  ما كسبه. السيطرة على منجم تضيف خامة سعة، والقتل يضيف خامة وحوش، وتحطيم
  كريستال خصم يضيف جوهراً وخامة بطل.
- **المعدات والصناديق**: **6 فتحات** (سلاح، خوذة، درع، حذاء، خاتم، قلادة)
  و**5 ندرات** (عادي، نادر، ملحمي، أسطوري، خرافي). الصناديق الموجودة على
  الخريطة تُفتح بلمسها (نصف قطر 34)، وتُزال من الخريطة، وتُطلق
  `ChestOpenedEvent` بمحتوى محدد بالبذرة؛ محتواها **معدات وأسلحة فقط**.
  العنصر المطابق (نفس الفتحة والندرة) يتحول إلى خامات معدات بدل تكراره،
  والعنصر غير المجهّز يمكن بيعه بالعملة الدائمة. **سقف مستوى المعدات 40**.
- **الترقيات**: لكل بطل صفحة مستقلة (اختيار البطل من الشريط العلوي)، ولكل
  نوع وحش صف/tab مستقل؛ يمكن ترقية بطل أو وحش غير مستخدم. شريط «القوة»
  يعرض قوة الحساب الإجمالية. ترقية البطل تزيد HP/الضرر، وترقية السعة ترفع
  حمل الموارد، وترقية المعدات ترفع خصائص القطعة؛ كل فئة تستهلك خامتها مع
  العملة. **`ProgressionController`** هو مصدر الحقيقة بين المباريات، ونسخة
  منه تُطبّق على `GameWorld` عبر `applyProgression` قبل القتال (HP الأقصى،
  ضرر/سرعة المعدات، سعة الحمل).
- **الواجهة**: مدخل «التطوير» في الشاشة الرئيسية وزر لكل بطل، يفتح
  `ProgressionScreen` بخمس صفحات: الأبطال، الوحوش، المعدات، الأسلحة،
  الصناديق. تُعرض المحفظة والخامات الأربع والقوة أعلى الصفحات. نافذة ترقية
  الوحوش داخل المباراة تعرض تكلفة الجوهر والأنسجة معاً وتمنع الترقية عند
  نقص أيّهما. HUD يستخدم `world.maxHp` بعد المعدات والترقيات.
- **الحفظ**: `HeroProgress` يحمل الآن `materials` و`equipment` و`equipped`
  و`capacityLevel` و`heroUpgradeLevel` إضافة إلى الحقول القديمة. التحميل
  يتجاهل الحقول غير المعروفة والعناصر التالفة، لذا ملفات اللاعبين القديمة
  تُفتح بدون خسارة (اختُبر صراحةً).
- **فحص Archero_fm**: المشروع القديم يضم متجر عملة بسيطاً (`shop_test.dart`)
  يشتري زيادة HP/هجوم بـ`globalCoins`، بلا فتحات أو ندرات أو خامات مستقلة
  أو صناديق أو مستويات معدات. لم يُنقل أي كود؛ النظام بُني جديداً بالكامل.
- **الاختبارات**: `test/progression_test.dart` = 29 اختباراً (النموذج،
  الندرات، المكررات، البيع، السقف 40، ترقيات البطل/الوحش/السعة، الحفظ
  والتوافق للخلف، فتح الصندوق باللمس، التسوية، تطبيق التقدم، وخمس صفحات
  الواجهة)، و3 اختبارات جديدة في `game_screen_test.dart`، وتحديث اختبارين
  في `monster_system_test.dart` للأرباح المعلّقة والخامات، ولقطة
  `35_progression.png` عبر golden ثابت في `test/goldens/progression.png`.
  الحزمة الكاملة كانت **230/230 ناجحة** عند هذه الخطوة، وأصبحت **246/246 ناجحة** بعد خطوة الأونلاين/الهوتسبوت، و`flutter analyze --no-pub` =
  **No issues found**.
- **قيم موازنة مبدئية غير نهائية**: أوزان الندرة 55/27/12/5/1، قيم القوة
  النسبية 1/1.25/1.6/2/2.5، قيم البيع والخامات، منحنى تكلفة الترقية،
  سقفا البطل والسعة (40 و20)، سعة 500+50×مستوى، ونسب تأثير المعدات؛ كلها
  موثقة هنا وتنتظر قرار رسمي في §5. النص يثبت الفتحات والندرات والسقف
  والمواد المستقلة فقط.
- **حدود معروفة**: لا توجد صفحة مستقلة لتخزين صناديق غير مفتوحة لأن النص
  يجعلها عناصر خريطة تُفتح باللمس؛ صفحة الصناديق تشرح القواعد وتعرض
  الاحتمالات. لا يوجد لاعبون أونلاين بعد، لذا لا منافس بشري يفتح الصناديق
  أو يشارك في الاقتصاد الدائمة. لا جهاز أندرويد في البيئة، فالتحقق من لمس
  الصندوق تم عبر اختبارات المحاكاة ولا يزال بحاجة لتجربة على الجهاز.

## 30. الأونلاين والهوتسبوت (2026-11-18)

بُنيت خطتا الأونلاين والهوتسبوت معاً لأنهما تشتركان في الخادم الحاسم وبروتوكول
الشبكة، ثم سُجّل كل نظام على حدة في الجدول أعلاه.

- **البروتوكول**: رسائل JSON سطر-بسطر فوق TCP، بإصدار ثابت
  `NetMessage.version = 1`. أي رسالة بإصدار مختلف تُرفض بدل تفسيرها خطأً.
  `LoopbackTransportPair` يوفّر زوج اتصال مستقل لكل عميل في الاختبارات،
  تماماً كما يوفّر `SocketTransport` مقبساً مستقلاً لكل لاعب في الواقع.
- **الخادم الحاسم**: `OnlineMatchServer` يملك حالة الضرر والقتل والنقاط
  والموارد والصحة والحركة عبر `MatchAuthority`. العميل يرسل نيّة فقط
  (موضع/هجوم/تدمير كريستال/التقاط)، والخادم يطبّق الحد الأقصى للضرر والمدى
  والسعة وحدود الخريطة. أي تجاوز يُسجّل في `violations` ويُرفض.
- **قواعد المباراة**: `MatchDuration` يعرض 10/20/30/45/60 دقيقة فقط،
  والمطابقة العشوائية لا تجمع إلا لاعبين اختاروا المدة نفسها.
  `decideMatch` يطبّق الانتهاء بالوقت (الأعلى نقاطاً ثم الأكثر كريستالات)
  أو بآخر لاعب يملك كريستالات. التعادل التام يُترك تعادلًا لأن النص لا يحدد
  معياراً ثالثاً. أربع ألوان مختلفة للاعبين، وأسماء وأشرطة HP في HUD.
- **الغرف والأصدقاء**: رموز دعوة من 6 أحرف، دعوة بالاسم، مالك الغرفة وحده
  يRemoved لاعب قبل البدء، مغادرة الغرفة بلا عقوبة، ومغادرة المباراة تُرسل
  `playerLeft` وتُحسب خسارة. `SocialService` يوفّر حسابات اسم/كلمة مرور
  محلية، بحثاً بالاسم، طلبات صداقة وقبولاً/رفضاً وإحصائيات الخصم.
- **الهوتسبوت**: `HotspotService` يربط الخادم على كل عناوين IPv4 بمنفذ
  ثابت 40404، ويعرض عناوين الشبكة للأجهزة الثلاثة للاتصال بها.
  اللقطات الحاسمة تُبثّ لكل الأجهزة. عند انقطاع الاتصال أو انتهاء المباراة
  تُحفظ النتيجة في `PendingResultStore` محلياً، وتُطبَّق على الحساب عند
  عودة الإنترنت عبر `syncToAccount` (مرة واحدة لكل نتيجة).
- **الواجهة**: `LobbyScreen` تجمع تسجيل الدخول، الأبطال الأربعة، المدة،
  نوع الاتصال، المطابقة والغرف والأصدقاء. `NetworkMatchScreen` يغلّف
  `GameScreen` بالمزامنة: يرسل الحركة والهجوم وتدمير الكريستالات والتقاط
  الموارد، ويعرض النقاط والمؤقت وأشرطة HP للأربعة، ويعرض شاشة النتيجة.
- **ما تركه النص غير محسوم (لا يُدعى إنجازه)**: ترحيل المضيف عند انقطاعه،
  تقنية الـbackend واختيار تقنية الشبكة النهائية، الـanti-cheat الإنتاجي،
  والحفظ السحابي عبر Google أو Apple — كلها تحتاج بيانات اعتماد أو
  قرار معماري خارجي، وسُجّلت مفتوحة في §5 بدل اختراع حل نهائي لها.
  الاتصال بالخادم الأونلاين افتراضياً يشير إلى `127.0.0.1` لأنه لا يوجد
  خادم منشور بعد؛ حقل العنوان قابل للتعديل في الواجهة.
- **الاختبارات**: `test/online_match_test.dart` = 12 اختباراً (المدد،
  المطابقة، الغرف، القواعد، منع الغش، الأصدقاء، 4 عملاء عبر loopback،
  اتصال TCP حقيقي)، `test/lobby_test.dart` = 3 اختبارات، ولقطة
  `36_online_lobby.png` عبر golden في `test/goldens/online_lobby.png`.

## 31. تدقيق القتال والأسلحة والقدرات (2026-11-18)

- **المنهج**: فُحص الكود الفعلي لا التقارير — `lib/game/combat/combo.dart`،
  `hero_kit.dart`، `lib/game/world/game_world.dart`، `lib/game/game_screen.dart`،
  ووثائق `docs/game/*_combat.md` و`special_abilities.md`، مع الجدول 3 في §7
  وسجل فحص Archero_fm في نفس القسم.
- **فحص Archero_fm**: لا يوجد نظام قتال أو أسلحة أو قدرات قابل للنقل في
  المشروع القديم بصيغة Archer FM (القتال القديم مرتبط بعارض SVG ومؤقت إطلاق
  منفصل، رُفض نقله في §11). لذلك بُني القتال من الصفر في §19–§24، والجديد هنا
  هو التدقيق والتوثيق لا إعادة البناء.
- **المطابق للنص (مُثبت بالكود والاختبارات)**: هجوم يدوي في كل ضغطة بلا هجوم
  تلقائي؛ كومبو خماسي 100/110/120/135/155% بنافذة 1800ms تُصفَّر عند تفويتها؛
  أربعة أسلحة بضرر ومدى ووتيرة وأقصى أهداف مختلفة (قوس مقذوف، سيف/خنجر/رمح
  قتال قريب) وكلها تهاجم أثناء الحركة؛ طاقة تتجدد وتبريد مستقل لكل قدرة؛
  16 قدرة (4 لكل بطل) بأقفال 1/10/20/30، وال Ultimate واحدة من الأربع لا
  خامسة؛ حرق Flame وسم Shadow يتراكمان على الهدف (DoT)؛ ضرر متزامن مع أحداث
  manifest (projectile_release/melee_impact/*_burst)؛ لا مقاومة حالات خاصة.
  إثبات: `test/combo_test.dart`، اختبارات `*_kit_test.dart` الأربعة،
  `test/game_world_test.dart`، `test/special_abilities_capture_test.dart`،
  ولقطات `ArenaPainter` بضرر محسوب من فرق HP فعلي.
- **الفجوات بعد الحسم**:
  1. ~~«التجميد والشلل يعطّلان الهدف مؤقتاً»~~ **حُسمت**: `PlayerState` و
     `EnemyState` يحملان `frozenUntilMs` / `stunnedUntilMs` و`disabledAt(now)`.
     `hell_burst` يشل الناجين 700ms، و`static_field` يجمّد القريبين عند
     التفعيل ثم أهداف كل طعنة مشحونة 900ms. أثناء التعطيل تتوقف الحركة
     والهجوم، ويُلغى `windup` الجاري. لا مقاومة حالات ولا ضرر إضافي؛ المدد
     موازنة مبدئية لأن المواصفة لم تعطِ أرقاماً.
  2. ~~«لا توجد آلية مراوغة»~~ **حُسمت**: أُزيل `requestDodge()` وكل حقوله
     ومناعته وتسارعه وتبريده، وأُزيل زر «مراوغة» وحالتها من آلة الحركات.
     أصل `dodge` في الـmanifest/GLB بقي كما هو دون استخدام قتالي. الكومبو
     يُصفّر الآن عند الضرر أو انتهاء النافذة فقط.
  3. ~~«لكل بطل ثلاثة أسلحة، واحد متاح واثنان يُفتحان بالتقدم»~~ **حُسمت في
     الخطوة 12**: أوضح المستخدم أن الاختيار يكون قبل الدخول للعبة، فبُنيت
     ثلاثة أسلحة لكل بطل (أساسي + بديل سريع عند المستوى 10 + بديل ثقيل عند
     المستوى 20) وتُختار في شاشة اخтиار الجيش قبل المباراة. الأسماء والأرقام
     موازنة مبدئية موثّقة في §32 لأن النص لم يحددها.
- **النتيجة**: الجوهر المبني سليم ومُختبر. بعد حسم فجوات القتال وُسّعت الحزمة
  إلى **270/270 ناجحة** و`flutter analyze --no-pub` = **No issues found!**.
  فجوات §31 الثلاث (الأسلحة، التجميد/الشلل، المراوغة) أصبحت محسومة؛ بقية
  عناصر §5 (الخلفية/النسخ المكتمل، المقاومات، أرقام الموازنة، الشبكة …) ما زالت
  مفتوحة ولا يُدعى إنجازها. لا بناء APK ولا اختبار لمس على جهاز في هذه المرحلة.

## 32. واجهات اللعبة وتجربة المستخدم (الخطوة 12، 2026-11-18)

- **طلب المستخدم الإضافي قبل الانتقال للخطوة 13**: «واجهة رئيسية أفقية مستوحاة
  من Archero، مع بطل 3D في المنتصف والتنقل بين المتجر والأبطال والتطوير بالسحب
  يميناً ويساراً. ووجود ٣ انواع اسلحة لكل شخصية يتم اختيارها قبل الدخول للعبة».
  نُفّذ داخل الخطوة 12 قبل أي عمل في الخطوة 13.
- **فحص Archero_fm**: فُحصت `lib/main.dart` (قائمة رأسية ببطاقات أبطال)،
  `lib/game_screen.dart` (HUD مبني بـStack وعصا تحكم وأزرار)،
  `test/widget_test.dart` و`test/shop_test.dart` (متجر عملة بسيط). لا يوجد بطل
  GLB ولا PageView أفقي ولا اختيار سلاح قبل المباراة؛ لذا بُنيت الواجهات جديداً
  ولم يُنقل كود إلا conceptually. `lib/audio_service.dart` مسجّل للخطوة 13.
- **الواجهة الرئيسية الأفقية** (`lib/game/home_screen.dart`،
  `MainMenuScreen`): `PageView` أفقي بثلاث بطاقات (المتجر · الأبطال · التطوير)
  مع مؤشر صفحات وسحب يمين/يسار، واتجاه RTL. بطل حقيقي مجلد يظهر ثابتاً في
  المنتصف عبر `Hero3DController`/`Hero3DModel` مع حركة idle، ويعود إلى أيقونة
  البطل عند غياب النموذج. المؤقّت يعمل فقط عند تحميل نموذج فعلي. أزرار: لعب
  (شاشة اختيار الجيش/السلاح)، إعدادات، وجماعي. متجر البطاقة يستخدم
  `ProgressionController` الحقيقي (العملة، قوة الحساب، ترقية البطل والسعة)
  ويحفظ عبر `HeroProgress.copyWith`؛ لم تُخترع أسعار أو عملة جديدة. شاشة الروستر
  القديمة بقيت في `lib/main.dart` باسم `HeroRosterScreen` لاختباراتها فقط.
- **اختيار السلاح قبل المباراة** (`lib/game/combat/hero_weapons.dart`،
  `hero_kit.dart`، `army_selection_screen.dart`، `game_screen.dart`،
  `world/game_world.dart`): لكل بطل 3 أسلحة — الأساسي (مستوى 1، يحافظ على
  أرقام الكيت الأصلية)، وبديل سريع (مستوى 10: ضرر ×0.85 / وتيرة ×1.3 /
  مدى ×0.9)، وبديل ثقيل (مستوى 20: ضرر ×1.35 / وتيرة ×0.8 / مدى ×1.2). هذه
  الأرقام **موازنة مبدئية موثّقة** لأن النص لم يحدد أسماءً أو قيماً؛ لا تُعدّ
  نهائية. `HeroKit.withWeapon()` يشتق كيتاً معدّلاً دون تغيير الأصل، وتُطبَّق
  المعاملات على الضرر ووتيرة الهجوم و`attackRange`/`projectileRange`/
  `currentMeleeRange`. شاشة ما قبل المباراة تعرض البطاقات الثلاث وتقفل
  المستوى 10/20 حتى يبلغ مستوى البطل المحفوظ ذلك، وتمرّر `weaponId` إلى
  `GameScreen`.
- **إعدادات التحكم** (`lib/game/settings.dart`, `settings_screen.dart`،
  `SettingsStore`): حجم أدوات التحكم وحجم العصا والجهة والإزاحة الرأسية، مع
  حفظ في SharedPreferences ومخزن ذاكرة للاختبارات، وتطبيقه على HUD في
  `GameScreen`.
- **الاختبارات**: `test/weapons_test.dart` = 7 اختبارات (3 أسلحة لكل بطل،
  أقفال 1/10/20، ثبات الكيت الأصلي، وصول المعاملات للمحاكاة)،
  `test/home_menu_test.dart` = 5 اختبارات (البطل 3D في المنتصف، الصفحات
  الثلاث، السحب يميناً ويساراً، تبديل البطل، فتح شاشة المباراة، وشراء حقيقي
  من المتجر)، `test/settings_test.dart` و`test/army_selection_test.dart`،
  و`test/ui_capture_test.dart` = 3 لقطات goldens. الحزمة الكاملة
  **269/269 ناجحة**، و`flutter analyze --no-pub` = **No issues found!**.
- **الإثبات البصري**: `test/goldens/ui_settings.png`،
  `ui_army_selection.png` (بعد إضافة قسم الأسلحة)، و`ui_main_menu.png`
  الجديدة، مع نسخها إلى `/tmp/opencode/merge/captures/` بالأسماء
  `37_ui_settings.png` و`38_ui_army_selection.png` و`39_ui_main_menu.png`.
  لقطة القائمة تستخدم بديل الأيقونة لأن اختبارات Flutter لا تحمّل GLB؛
  مسار التحميل الحقيقي مُختبر في `hero3d_screen_test.dart`.
- **الحدود**: لا بناء APK ولا اختبار لمس على جهاز حقيقي في هذه المرحلة؛
  أرقام الأسلحة ومدد freeze/stun قابلة للتعديل بعد موازنة اللعب. فجوتا
  freeze/stun والمراوغة حُسمتا في §31. لم تُلَمس أصول الأبطال؛ حجم
  `assets/heroes/storm/storm.glb` ما زال 21,599,708 بايت.

## 33. حسم فجوات القتال (بعد الخطوة 12، 2026-11-18)

- **طلب المستخدم**: «نفّذ الفجوات وصلّحها كلها» في إشارة إلى فجوتي §31
  المتبقيتين: تجميد/شلل، ووجود آلية مراوغة رغم نفيها في المواصفة.
- **التجميد والشلل**: `PlayerState` و`EnemyState` أصبحا يحملان
  `frozenUntilMs` / `stunnedUntilMs` و`disabledAt(now)`؛ تغطّي الحالتان
  اللاعب والأعداء والجيش. أثناء التعطيل تتوقف الحركة والهجوم، ويُلغى أي
  `windup` جارٍ. `hell_burst` (Flame، مستوى 20) يشلّ الناجين داخل نصف قطر
  140 لمدة 700ms؛ `static_field` (Storm، مستوى 20) يجمّد القريبين عند
  التفعيل ثم أهداف كل طعنة مشحونة 900ms داخل نافذته البالغة 8 ثوانٍ. نافذة
  `staticFieldUntilMs` منفصلة عن الـbuff العام حتى لا يجمّد `tempest_rage`
  وحده. المدد أرقام موازنة مبدئية لأن النص حدد «تعطيلاً مؤقتاً» دون مدة.
- **المراوغة**: أُزيلت بالكامل من `GameWorld` (`requestDodge`، الحقول،
  المناعة، التسارع، التبريد، وتصفير الكومبو) ومن HUD (`btn_dodge`) ومن آلة
  الحركات. مقطع `dodge` في الـmanifest وملف GLB بقي كما هو كأصل أنيميشن فقط،
  دون أي تأثير لعبي. اختبار الشاشة يؤكد غياب الزر والنص.
- **الاختبارات**: استُبدلت اختبارات المراوغة بثلاثة اختبارات وهي: إلغاء
  استعداد عدو بـ`hell_burst`، توقف حركة عدو حتى انتهاء الشلل، وتجميد
  `static_field` عند التفعيل وعلى الطعنة المشحونة. أُضيف اختبار غياب زر
  المراوغة في `game_screen_test.dart`، واختبار كليب المهارة في
  `hero3d_screen_test.dart` بدل كليب المراوغة. الحزمة الكاملة
  **270/270 ناجحة**، و`flutter analyze --no-pub` = **No issues found!**.
- **الوثائق**: `hero_kit.dart`، `docs/game/ranger_combat.md`،
  `flame_combat.md`، `storm_combat.md`، `special_abilities.md`، و§5/§31
  تحدّثت كلها لتعكس الحالة الجديدة. لا بناء APK ولا لمس على جهاز حقيقي.
