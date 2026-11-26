# Match Rules Foundation

This package implements only the confirmed four-player FFA match rules:
- Approved match lengths: 10, 20, 30, 45, and 60 minutes.
- A single remaining non-forfeited player who still owns crystals wins immediately.
- At time expiry, rank by score, then by living crystal count.
- A complete tie remains explicitly unresolved; no hidden tiebreaker is invented.
- Forfeits remove a player from eligibility; the last remaining crystal holder wins if exactly one remains.
- Leaving an active match is a forfeit/loss.
- Score values are supplied by the authoritative gameplay systems; this package does not invent reward amounts.

## Integration boundary
The engine does not own the map, castles, crystals, hero, monster, economy, UI, network, or persistence systems. The match host must call `setLivingCrystals` with the castle authority's current count and `addScore` with points already computed by the approved scoring rules.

## Deliberately unresolved
The product requirements do not define what should happen if all players lose every crystal, nor how to break a tie after both score and crystal count are equal. The engine exposes `allRemainingPlayersHaveNoCrystals` and returns a tied result rather than guessing.

Hero lifecycle is owned by the authoritative combat runtime: a defeated hero loses 20% of the current wallet (integer loss rounded down), waits 10 seconds, respawns at the server-recorded spawn position with full health, and receives 5 seconds of damage protection. A death transition applies the wallet penalty once; reconnecting does not repeat it. Kill points/rewards remain intentionally unconfigured until their values and eligible kill events are approved.


## واجهة تجهيز المباراة العربية — 2026-11-26

- أضيفت شاشة تجهيز مباراة RTL مرتبطة بعارض الأبطال عبر زر «تجهيز المباراة».
- تسمح الشاشة بإدخال عنوان WebSocket يحدده المشغّل، إنشاء غرفة أو الانضمام برمز، ومتابعة حالة الاتصال ورمز الغرفة.
- اختيار البطل من الأبطال الأربعة واختيار السلاح الابتدائي المفتوح؛ الأسلحة الأخرى تظهر مقفلة بدلاً من إرسال طلبات غير مضمونة.
- تعرض الضربات الخاصة الأربع ومستويات فتحها منفصلة عن كومبو الخمس ضربات.
- اختيار الجيش الابتدائي يفرض 20 وحدة بالضبط من الأنواع الأربعة قبل الإرسال.
- ترسل الشاشة أوامر `select` و`army_select` وطلب `start` عبر `GameClient`; قبول بدء المباراة يبقى حصراً بقرار الخادم عندما يكتمل اللاعبون الأربعة.
- عنوان الخادم غير محدد افتراضياً عمداً؛ لا توجد خدمة إنتاجية أو عنوان استضافة موثق في المستودع. يلزم توفير عنوان WebSocket لخادم مضبوط بكتالوج القتال المعتمد.
- أضيفت اختبارات واجهة لاكتمال خيارات الأبطال والوحوش ولمنع تجاوز 20 وحدة.


## لوحة المباراة المباشرة — 2026-11-26

- شاشة التجهيز تتابع الآن رسائل `state` الدورية من الخادم وتعرض لوحة حالة عند بدء المباراة أو انتهائها.
- تعرض اللوحة صحة البطل وحالة الإحياء، رصيد الموارد، عدد البلورات الباقية من أصل سبع، عدد الوحوش الحية، وترتيب النقاط والبلورات للاعبين.
- كل الأرقام مأخوذة من اللقطة السلطوية للخادم؛ لا يحسب العميل نقاطاً أو صحة أو موارد محلياً.
- هذه لوحة معلومات حية وليست بعدُ مشهد ساحة اللعب المرئي؛ ربط رسم الخريطة ثلاثية الأبعاد/المائلة وعناصر التحكم داخل المشهد ما زال عملاً مستقلاً.
