# تدقيق وتثبيت ضربات الـSpecial — الأبطال الأربعة

> حالة: **مكتمل داخل الكود والاختبارات والإثبات البصري**. التبقي الوحيد خارج
> نطاق هذه البيئة هو التجربة اليدوية على جهاز حقيقي (انظر نهاية الملف).
> المصدر الوحيد للأسماء والأرقام: `lib/game/combat/hero_kit.dart` — لا تقارير.

## 1) منهجية التدقيق (من الكود، لا من الواجهة)

لكل قدرة من الـ16 تم التحقق من خمس نقاط في الكود:

1. **التعريف**: موجودة في `HeroKit.abilities` بـ`id` + `nameAr` + `descAr` +
   `unlockLevel` + `cooldownMs` + `energyCost` (+ `usesAttackClip`).
2. **الربط القتالي**: لها حالة تنفيذ فعلية في `GameWorld` — إما
   `releaseWeaponPayload` (قدرات كليب الهجوم) أو `_fireAbilityVolley` (قدرات
   كليب المهارة) أو تعديل buff/DoT حقيقي.
3. **الأنيميشن والحدث**: كليب `skill_*` مع حدث `*_burst`/`volley_release`، أو
   كليب `attack_*` مع `melee_impact`/`projectile_release` — انظر manifests.
4. **المؤثر البصري**: `slash`/`burst`/`bolt` في `ArenaPainter` أو
   zones/waves/veil/projectiles.
5. **قفل المستوى**: `useAbility` يرفض أي قدرة `unlockLevel > level`، وأي طاقة
   ناقصة، وأي cooldown فعّال، وأي استخدام أثناء قدرة معلّقة.

**لا تداخل مع الكومبو**: `useAbility` لا يلمس `combo` إطلاقاً، و`requestAttack`
يُرفض أثناء `pendingAbilityId != null` — مثبت باختبارات مخصصة (القسم 4).

**حالتا التعطيل**: `hell_burst` يشلّ الناجين 700ms، و`static_field` يجمّد
الأهداف 900ms (عند التفعيل وعلى كل طعنة مشحونة). كلتاهما تمنع الحركة والهجوم
وتُلغي أي استعداد `windup` جارٍ، دون مقاومة حالات أو ضرر إضافي. المدد أرقام
موازنة مبدئية لأن المواصفة حددت «تعطيلاً مؤقتاً» دون مدة.

## 2) القدرات الـ16 — الجدول الكامل

### Ranger II — `ranger_new` (قوس الطاقة الخضراء، ضرر أساسي 12)

| المستوى | القدرة | الطاقة | التبريد | التأثير القتالي الفعلي | الأنيميشن/الحدث | دليل بصري |
|---|---|---|---|---|---|---|
| 1 | وابل متعدد `multi_shot` | 25 | 6s | 5 سهام × 60% في زاوية واسعة | skill → `volley_release@5` | `03_multi_shot_volley.png` |
| 10 | سهم ثاقب `piercing_shot` | 30 | 8s | سهم واحد 220% يخترق 99 هدفاً (كبير ومرئي) | attack → `projectile_release@5` | `13_ranger_piercing_shot.png` |
| 20 | مطر السهام `arrow_rain` | 40 | 12s | منطقة نصف قطر 150: 8 نبضات × 35% كل 250ms | skill → `volley_release@5` | `04_arrow_rain_zone.png` |
| 30 | اندفاع الرياح `gale_surge` | 35 | 20s | 6s: ضرر ×1.2، وتيرة هجوم ×1.5، حركة ×1.25 + موجة خضراء | skill → `volley_release@5` | `14_ranger_gale_surge.png` |

### Flame — `flame` (سيف اللهب، ضرر أساسي 16)

| المستوى | القدرة | الطاقة | التبريد | التأثير القتالي الفعلي | الأنيميشن/الحدث | دليل بصري |
|---|---|---|---|---|---|---|
| 1 | ضربة اللهب `flame_slash` | 25 | 6s | 180% قوس أمامي + حرق 3 نبضات × 25% | attack → `melee_impact@3` | `06_flame_slash.png` |
| 10 | موجة النار `fire_wave` | 30 | 9s | موجة متحركة 160%، سرعة 260، مدى 320، تصيب كل من تعبره مرة | skill → `inferno_burst@4` | `08_flame_fire_wave.png` |
| 20 | انفجار الجحيم `hell_burst` | 40 | 12s | 220% لكل عدو داخل نصف قطر 140 + شلل 700ms للناجين | skill → `inferno_burst@4` | `07_flame_hell_burst.png` |
| 30 | هياج اللهب `inferno_rage` | 35 | 20s | 6s: ضرر ×1.25، وتيرة ×1.4، مدى ×1.2 + حلقة انفجار | skill → `inferno_burst@4` | `15_flame_inferno_rage.png` |

### Shadow — `shadow` (خناجر الظل، ضرر أساسي 14)

| المستوى | القدرة | الطاقة | التبريد | التأثير القتالي الفعلي | الأنيميشن/الحدث | دليل بصري |
|---|---|---|---|---|---|---|
| 1 | أنياب التوأم `twin_fangs` | 25 | 6s | 3 طعنات × 80% على الهدف الأمامي | attack → `melee_impact@3` | `16_shadow_twin_fangs.png` |
| 10 | حجاب الظل `shadow_veil` | 30 | 14s | 4s مناعة كاملة + سرعة ×1.35 + شفافية 0.55 للبطل | skill → `shadow_burst@4` | `11_shadow_veil.png` |
| 20 | معطف السم `venom_coat` | 40 | 16s | 8s: كل طعنة تسمم 2 × 15% + ضرر ×1.15 + حلقة سم | skill → `shadow_burst@4` | `17_shadow_venom_coat.png` |
| 30 | إعدام الظل `shadow_execute` | 35 | 18s | انتقال فوري لأضعف عدو + 300% | skill → `shadow_burst@4` | `12_shadow_execute.png` |

### Storm — `storm` (رمح الصاعقة، ضرر أساسي 15)

| المستوى | القدرة | الطاقة | التبريد | التأثير القتالي الفعلي | الأنيميشن/الحدث | دليل بصري |
|---|---|---|---|---|---|---|
| 1 | طعنة الصاعقة `thunder_thrust` | 25 | 6s | 160% طعنة + سلسلة 60% من الضرر لأقرب جار ≤200 مع رسم برق | attack → `melee_impact@3` | `18_storm_thunder_thrust.png` |
| 10 | برق متسلسل `chain_lightning` | 30 | 9s | 3 أقرب أعداء ≤180 بـ130% لكل واحد + برق متعرج `bolt` لكل هدف | skill → `storm_burst@4` | `19_storm_chain_lightning.png` |
| 20 | حقل السكون `static_field` | 40 | 15s | 8s: كل طعنة تطلق شحنة ثانية 40% وتجمّد الهدف 900ms + تجميد فوري للقريبين + حلقة صدمة | skill → `storm_burst@4` | `32_storm_static_field.png` |
| 30 | غضب العاصفة `tempest_rage` | 35 | 20s | 6s: ضرر ×1.2، وتيرة ×1.3، مدى الرمح ×1.25 (125→156) + حلقة | skill → `storm_burst@4` | `33_storm_tempest_rage.png` |

## 3) الإثبات البصري داخل اللعبة

كل اللقطات مولّدة عبر `ArenaPainter` الحقيقي + `GameWorld` حقيقي + مجسم GLB
الحقيقي للبطل (لا صور أزرار). اللقطات تعرض حالة القتال في لحظة تنفيذ القدرة،
وتحمل فوق الأعداء أرقام الضرر الفعلية المحسوبة من فرق HP الحقيقي.

- قدرات قديمة موثقة: `03` (multi_shot)، `04` (arrow_rain)، `06` (flame_slash)،
  `07` (hell_burst)، `08` (fire_wave)، `11` (shadow_veil)، `12` (shadow_execute).
- قدرات جديدة موثقة في هذه الجولة (9 لقطات):
  `13_ranger_piercing_shot`، `14_ranger_gale_surge`، `15_flame_inferno_rage`،
  `16_shadow_twin_fangs`، `17_shadow_venom_coat`، `18_storm_thunder_thrust`،
  `19_storm_chain_lightning`، `32_storm_static_field`، `33_storm_tempest_rage`.
- مولد اللقطات: `test/special_abilities_capture_test.dart` — يشترط أن اللقطة
  تحمل ضرراً فعلياً على الأقل على دمية واحدة (`labels` غير فارغة + HP انخفض)،
  وأن المجسم الحقيقي رسم مثلثات > 0.

## 4) الاختبارات — تغطية النقاط السبع المطلوبة

| المطلوب | مكان الإثبات |
|---|---|
| 4 قدرات مستقلة لكل بطل | `test/ranger_kit_test.dart`، `flame_kit_test.dart`، `shadow_kit_test.dart`، `storm_kit_test.dart` (length == 4 + المستويات [1,10,20,30] + المعرفات) |
| الفتح عند المستوى الصحيح | `test/game_world_test.dart` → «locked ability is rejected…» + «ability levels gate the flame/shadow/storm kit the same way» |
| القدرة المغلقة مرفوضة | نفس الاختبارات أعلاه (`useAbility` == null قبل الفتح) |
| تأثير قتالي حقيقي | مجموعات Flame/Shadow/Storm في `game_world_test.dart` + «multi_shot fires five arrows» + «arrow_rain ticks AoE damage» + لقطات القسم 3 |
| احتساب الضرر والتأثيرات بدقة | اختبارات النسب: 5×60%، 220% اختراق، 8×35%، 180%+حرق 3×25%، 160% موجة، 220% انفجار + شلل 700ms، 3×80%، 300% تنفيذ، 160%+60% سلسلة، 3×130% برق، شحنة 40% + تجميد 900ms، buffs ×1.2/1.3/1.25 |
| الطاقة والـCooldown | `game_world_test.dart` → «ability costs energy and normal attacks refill some» + مجموعة «ability energy and cooldown work for every hero» (4 أبطال × قدرة المستوى 1) |
| عدم التداخل مع كومبو الخمس ضربات | `game_world_test.dart` → مجموعة «special abilities stay independent of the five-hit combo» (Ranger/Flame/Shadow/Storm: القدرة لا تقدّم ولا تُصفّر السلسلة، والهجوم العادي مرفوض أثناء قدرة معلّقة، والسلسلة تصل 155% كما هي) |

النتيجة النهائية: **116/116 اختبار ناجح** و`flutter analyze --no-pub`: **No issues found**.
(زيادة اختبار واحد عن جولة التدقيق: حارس `test/hero_animation_test.dart` الذي
يمنع رجوع كليبات الحركة المجمّدة — انظر القسم 24 في `PROJECT_STATUS.md`.)

## 5) إصلاحات هذه الجولة

- `gale_surge` (Ranger) و`venom_coat` (Shadow): كانا يغيّران الحالة القتالية فعلياً
  لكن **بلا أي مؤثر بصري لحظي** — أُضيف لكل منهما `burst` بلون البطل ليظهر
  التفعيل داخل الحلبة مثل باقي الـbuffs.
- حُذف كود debug قديم في `lib/game/render3/hero3d_painter.dart` كان يطبع
  `DBG giant` كل إطار عند تجاوز إحداثي شاشة 500 (ضجيج إنتاجي بلا وظيفة).

## 6) ما بقي خارج نطاق البيئة

- التجربة اليدوية النهائية على جهاز حقيقي (لمس الأزرار الأربعة لكل بطل أثناء
  معركة فعلية والاستماع/مشاهدة الأنيميشن الحقيقي) — هذه البيئة تعمل بلا شاشة
  لمس ولا صوت، والإثبات هنا هو لقطات `ArenaPainter` + اختبارات حالة القتال.
