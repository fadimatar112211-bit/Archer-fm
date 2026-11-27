import 'package:flutter/material.dart';

import 'player_account_data_service.dart';
import 'supabase_account_service.dart';

class PlayerAccountScreen extends StatefulWidget {
  const PlayerAccountScreen({required this.accountService, super.key});

  final SupabaseAccountService accountService;

  @override
  State<PlayerAccountScreen> createState() => _PlayerAccountScreenState();
}

class _PlayerAccountScreenState extends State<PlayerAccountScreen> {
  late final PlayerAccountDataService _data;
  PlayerProfile? _profile;
  PlayerWallet? _wallet;
  PlayerMonsterProgress? _monsterProgress;
  List<PlayerCurrencyTransaction> _transactions = const [];
  List<PlayerMatchResult> _matches = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.accountService.playerData;
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
        _data.loadMonsterProgress(),
        _data.loadCurrencyHistory(limit: 12),
        _data.loadRecentMatches(limit: 12),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = values[0] as PlayerProfile;
        _wallet = values[1] as PlayerWallet;
        _monsterProgress = values[2] as PlayerMonsterProgress;
        _transactions = values[3] as List<PlayerCurrencyTransaction>;
        _matches = values[4] as List<PlayerMatchResult>;
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

  Future<void> _signOut() async {
    await widget.accountService.signOut();
    if (mounted) Navigator.of(context).pop();
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
                      Text('مستويات الوحوش', style: Theme.of(context).textTheme.titleLarge),
                      Card(
                        child: Column(
                          children: [
                            _monsterLevelTile('العدّاء', _monsterProgress?.runner),
                            _monsterLevelTile('المدرّع', _monsterProgress?.tank),
                            _monsterLevelTile('المتسلّل', _monsterProgress?.stalker),
                            _monsterLevelTile('الرامي', _monsterProgress?.ranged),
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

  Widget _monsterLevelTile(String title, int? level) => ListTile(
        dense: true,
        leading: const Icon(Icons.pets_outlined),
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
