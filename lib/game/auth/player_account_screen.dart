import 'package:flutter/material.dart';

import '../heroes/hero_roster.dart';

import 'player_account_data_service.dart';
import 'player_progression_purchase_client.dart';
import 'supabase_account_service.dart';

class PlayerAccountScreen extends StatefulWidget {
  const PlayerAccountScreen({required this.accountService, super.key});

  final SupabaseAccountService accountService;

  @override
  State<PlayerAccountScreen> createState() => _PlayerAccountScreenState();
}

class _PlayerAccountScreenState extends State<PlayerAccountScreen> {
  late final PlayerAccountDataService _data;
  late final PlayerProgressionPurchaseClient _purchaseClient;
  ProgressionPurchaseCatalog? _purchaseCatalog;
  final Set<String> _busyPurchases = {};
  PlayerProfile? _profile;
  PlayerWallet? _wallet;
  PlayerHeroProgress? _heroProgress;
  PlayerMonsterProgress? _monsterProgress;
  List<PlayerCurrencyTransaction> _transactions = const [];
  List<PlayerMatchResult> _matches = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.accountService.playerData;
    _purchaseClient = PlayerProgressionPurchaseClient(accountService: widget.accountService);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        _data.loadProfile(),
        _data.loadWallet(),
        _data.loadHeroProgress(),
        _data.loadMonsterProgress(),
        _data.loadCurrencyHistory(limit: 12),
        _data.loadRecentMatches(limit: 12),
      ]);
      ProgressionPurchaseCatalog? catalog;
      try {
        catalog = await _purchaseClient.loadCatalog();
      } catch (_) {
        // Account data remains readable while the purchase gateway is deployed.
      }
      if (!mounted) return;
      setState(() {
        _purchaseCatalog = catalog;
        _profile = values[0] as PlayerProfile;
        _wallet = values[1] as PlayerWallet;
        _heroProgress = values[2] as PlayerHeroProgress;
        _monsterProgress = values[3] as PlayerMonsterProgress;
        _transactions = values[4] as List<PlayerCurrencyTransaction>;
        _matches = values[5] as List<PlayerMatchResult>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات الحساب. تحقق من الاتصال وحاول مجدداً.';
        _loading = false;
      });
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _profile?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم اللاعب'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(
            labelText: 'اسم اللاعب',
            hintText: 'اكتب اسماً من 1 إلى 32 حرفاً',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      final profile = await _data.updateDisplayName(name);
      if (!mounted) return;
      setState(() => _profile = profile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث اسم اللاعب')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث الاسم. تحقق من طوله وحاول مجدداً.')),
      );
    }
  }

  Future<void> _confirmPurchase({
    required String purchaseType,
    required String targetId,
    required String title,
    required int cost,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Text('سيتم خصم $cost عملة لشراء أو تطوير $title. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _purchase(purchaseType, targetId);
    }
  }

  Future<void> _purchase(String purchaseType, String targetId) async {
    final key = '$purchaseType:$targetId';
    if (_busyPurchases.contains(key)) return;
    setState(() => _busyPurchases.add(key));
    try {
      final receipt = await _purchaseClient.purchase(
        purchaseType: purchaseType,
        targetId: targetId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receipt.alreadyApplied
                ? 'تم تأكيد العملية السابقة دون خصم جديد'
                : purchaseType == 'weapon_unlock'
                    ? 'تم فتح السلاح بنجاح • الرصيد ${receipt.currencyBalance}'
                    : 'تم التطوير إلى المستوى ${receipt.resultingLevel} • الرصيد ${receipt.currencyBalance}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final code = error is ProgressionPurchaseException ? error.code : '';
      final message = switch (code) {
        'insufficient_currency' => 'رصيدك من العملات غير كافٍ',
        'weapon_locked' => 'افتح السلاح أولاً',
        'weapon_already_unlocked_or_invalid_save' => 'السلاح مفتوح مسبقاً',
        'weapon_max_level' || 'monster_max_level' || 'weapon_max_level_or_unknown' || 'monster_max_level_or_invalid' => 'وصلت إلى المستوى الأقصى',
        'progression_purchase_revision_conflict' => 'تغيّرت بياناتك؛ حدّث الحساب وحاول مجدداً',
        'purchase_service_not_configured' || 'purchase_service_unavailable' => 'خدمة الشراء غير مهيأة حالياً',
        'unauthorized' => 'انتهت جلسة الحساب؛ سجّل الدخول مجدداً',
        _ => 'تعذرت العملية. تحقق من الاتصال وحاول مجدداً.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      try {
        await _load();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _busyPurchases.remove(key));
    }
  }

  Map<String, dynamic>? _weaponQuote(String id) {
    for (final item in _purchaseCatalog?.weapons ?? const <Map<String, dynamic>>[]) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  Map<String, dynamic>? _monsterQuote(String id) {
    for (final item in _purchaseCatalog?.monsters ?? const <Map<String, dynamic>>[]) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  Future<void> _signOut() async {
    await widget.accountService.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _purchaseClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب اللاعب'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(_profile?.displayName ?? 'لا يوجد اسم للاعب'),
                          subtitle: Text(widget.accountService.currentUser?.email ?? ''),
                          trailing: IconButton(
                            tooltip: 'تعديل الاسم',
                            onPressed: _editDisplayName,
                            icon: const Icon(Icons.edit),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.monetization_on, color: Color(0xFFFFC857)),
                          title: const Text('رصيد العملات'),
                          subtitle: Text('رقم إصدار الحفظ: ${_wallet?.progressionRevision ?? 0}'),
                          trailing: Text(
                            '${_wallet?.permanentCurrency ?? 0}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('مستويات الأبطال', style: Theme.of(context).textTheme.titleLarge),
                      Card(
                        child: Column(
                          children: [
                            _heroLevelTile('رينجر', _heroProgress?.rangerLevel),
                            _heroLevelTile('فليم', _heroProgress?.flameLevel),
                            _heroLevelTile('شادو', _heroProgress?.shadowLevel),
                            _heroLevelTile('ستورم', _heroProgress?.stormLevel),
                            const Divider(height: 1),
                            ListTile(
                              dense: true,
                              title: const Text('الأسلحة المفتوحة'),
                              trailing: Text('${_heroProgress?.unlockedWeaponCount ?? 0}'),
                            ),
                            ListTile(
                              dense: true,
                              title: const Text('الأسلحة المطوّرة'),
                              trailing: Text('${_heroProgress?.weaponUpgradeCount ?? 0}'),
                            ),
                          ],
                        ),
                      ),
                      if (_purchaseCatalog == null)
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text('خدمة الشراء غير متاحة حالياً'),
                            subtitle: Text('يلزم ربط عنوان خادم اللعبة وإعداد أسعار التطوير المعتمدة.'),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text('الأسلحة وفتحها وتطويرها', style: Theme.of(context).textTheme.titleLarge),
                      for (final hero in archerFmHeroes)
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.shield_outlined),
                                title: Text(hero.nameAr),
                                subtitle: Text(hero.roleAr),
                              ),
                              for (final weapon in hero.weapons)
                                _weaponPurchaseTile(weapon),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text('مستويات الوحوش', style: Theme.of(context).textTheme.titleLarge),
                      Card(
                        child: Column(
                          children: [
                            _monsterPurchaseTile('runner', 'العدّاء', _monsterProgress?.runner),
                            _monsterPurchaseTile('tank', 'المدرّع', _monsterProgress?.tank),
                            _monsterPurchaseTile('stalker', 'المتسلّل', _monsterProgress?.stalker),
                            _monsterPurchaseTile('ranged', 'الرامي', _monsterProgress?.ranged),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('سجل العملات', style: Theme.of(context).textTheme.titleLarge),
                      if (_transactions.isEmpty)
                        const ListTile(title: Text('لا توجد حركات مسجلة بعد'))
                      else
                        for (final transaction in _transactions)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              transaction.amount >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                              color: transaction.amount >= 0 ? Colors.green : Colors.orange,
                            ),
                            title: Text(_transactionLabel(transaction.reason)),
                            subtitle: Text(transaction.referenceId ?? ''),
                            trailing: Text(
                              transaction.amount > 0 ? '+${transaction.amount}' : '${transaction.amount}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      const Divider(height: 28),
                      Text('آخر المباريات', style: Theme.of(context).textTheme.titleLarge),
                      if (_matches.isEmpty)
                        const ListTile(title: Text('لا توجد مباريات محفوظة بعد'))
                      else
                        for (final match in _matches)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(child: Text('#${match.placement}')),
                            title: Text('النتيجة: ${match.score} نقطة'),
                            subtitle: Text('البلورات المتبقية: ${match.crystalsRemaining} • ${match.finishReason}'),
                            trailing: Text(match.completedAt == null
                                ? ''
                                : '${match.completedAt!.toLocal().day}/${match.completedAt!.toLocal().month}'),
                          ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _weaponPurchaseTile(HeroWeapon weapon) {
    final quote = _weaponQuote(weapon.id);
    final owned = _heroProgress?.ownsWeapon(weapon.id) ?? false;
    final level = _heroProgress?.weaponLevel(weapon.id) ?? 0;
    final cost = quote?['cost'];
    final available = quote?['available'] == true && cost is int;
    final purchaseType = quote?['purchaseType'] as String? ??
        (owned ? 'weapon_upgrade' : 'weapon_unlock');
    final busyKey = '$purchaseType:${weapon.id}';
    return ListTile(
      dense: true,
      title: Text(weapon.nameAr),
      subtitle: Text(owned ? 'المستوى $level / 40' : 'مغلق'),
      trailing: SizedBox(
        width: 128,
        child: FilledButton.tonal(
          onPressed: available && !_busyPurchases.contains(busyKey)
              ? () => _confirmPurchase(
                    purchaseType: purchaseType,
                    targetId: weapon.id,
                    title: weapon.nameAr,
                    cost: cost as int,
                  )
              : null,
          child: Text(
            quote == null
                ? 'غير متاح'
                : available
                    ? '${owned ? 'تطوير' : 'فتح'} • $cost'
                    : owned && level >= 40
                        ? 'الحد الأقصى'
                        : 'غير متاح',
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _monsterPurchaseTile(String id, String title, int? level) {
    final quote = _monsterQuote(id);
    final cost = quote?['cost'];
    final available = quote?['available'] == true && cost is int;
    const purchaseType = 'monster_upgrade';
    final busyKey = '$purchaseType:$id';
    return ListTile(
      dense: true,
      leading: const Icon(Icons.pets_outlined),
      title: Text(title),
      subtitle: Text(level == null ? '—' : 'المستوى $level / 40'),
      trailing: SizedBox(
        width: 128,
        child: FilledButton.tonal(
          onPressed: available && !_busyPurchases.contains(busyKey)
              ? () => _confirmPurchase(
                    purchaseType: purchaseType,
                    targetId: id,
                    title: title,
                    cost: cost as int,
                  )
              : null,
          child: Text(
            quote == null
                ? 'غير متاح'
                : available
                    ? 'تطوير • $cost'
                    : (level ?? 1) >= 40
                        ? 'الحد الأقصى'
                        : 'غير متاح',
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _heroLevelTile(String title, int? level) => ListTile(
        dense: true,
        leading: const Icon(Icons.shield_outlined),
        title: Text(title),
        trailing: Text(
          level == null ? '—' : 'المستوى $level / 40',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  String _transactionLabel(String reason) => switch (reason) {
        'match_reward' => 'مكافأة مباراة',
        'weapon_upgrade' => 'تطوير سلاح',
        'monster_upgrade' => 'تطوير وحوش',
        _ => reason,
      };
}
