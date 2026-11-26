import 'dart:async';

import 'package:flutter/material.dart';

import 'match_target_selector.dart';
import 'match_result_panel.dart';

import '../../monsters/monster_models.dart';

import '../controls/virtual_joystick.dart';
import '../render3/arena_battlefield.dart';
import '../heroes/hero_roster.dart';
import '../network/game_client.dart';

class MatchLoadoutScreen extends StatefulWidget {
  const MatchLoadoutScreen({super.key});

  @override
  State<MatchLoadoutScreen> createState() => _MatchLoadoutScreenState();
}

class _MatchLoadoutScreenState extends State<MatchLoadoutScreen> {
  final _url = TextEditingController();
  final _roomCode = TextEditingController();
  final _counts = <MonsterType, int>{
    MonsterType.runner: 5,
    MonsterType.tank: 5,
    MonsterType.stalker: 5,
    MonsterType.ranged: 5,
  };
  final _events = <String>[];
  GameClient? _client;
  StreamSubscription<Map<String, dynamic>>? _messages;
  StreamSubscription<GameConnectionState>? _states;
  HeroCombatDefinition _hero = archerFmHeroes.first;
  int _weaponIndex = 0;
  int _durationMinutes = 30;
  String? _room;
  String? _playerId;
  int _playersCount = 0;
  bool _allPlayersReady = false;
  String _matchPhase = 'waiting';
  Map<String, dynamic>? _latestState;
  String _connectionLabel = 'غير متصل';
  String? _lastError;
  bool _busy = false;
  bool _lastAttemptCreate = true;
  Timer? _connectionDeadline;

  int get _armyTotal => _counts.values.fold(0, (sum, value) => sum + value);

  @override
  void dispose() {
    _connectionDeadline?.cancel();
    _messages?.cancel();
    _states?.cancel();
    _client?.dispose();
    _url.dispose();
    _roomCode.dispose();
    super.dispose();
  }

  Future<void> _connect({required bool create}) async {
    final url = _url.text.trim();
    if (!(url.startsWith('ws://') || url.startsWith('wss://'))) {
      setState(() => _lastError = 'أدخل عنوان خادم يبدأ بـ ws:// أو wss://');
      return;
    }
    if (!create && _roomCode.text.trim().isEmpty) {
      setState(() => _lastError = 'أدخل رمز الغرفة أولاً');
      return;
    }
    await _disposeClient();
    _lastAttemptCreate = create;
    final client = GameClient(url);
    _client = client;
    _messages = client.messages.listen(_onMessage);
    _states = client.states.listen((state) {
      if (!mounted) return;
      setState(() {
        _connectionLabel = switch (state) {
          GameConnectionState.connected => 'متصل',
          GameConnectionState.connecting => 'جارٍ الاتصال',
          GameConnectionState.reconnecting => 'إعادة الاتصال',
          GameConnectionState.sessionExpired => 'انتهت الجلسة',
          GameConnectionState.closed => 'مغلق',
          GameConnectionState.disconnected => 'غير متصل',
        };
        if (state == GameConnectionState.sessionExpired ||
            state == GameConnectionState.closed) {
          _busy = false;
          _connectionDeadline?.cancel();
          if (state == GameConnectionState.sessionExpired) {
            _lastError =
                'انتهت صلاحية الغرفة؛ أنشئ غرفة جديدة أو انضم إلى غرفة أخرى';
          }
        }
      });
    });
    setState(() {
      _busy = true;
      _lastError = null;
      _room = null;
      _events.clear();
    });
    _connectionDeadline?.cancel();
    _connectionDeadline = Timer(const Duration(seconds: 12), () {
      if (!mounted || !identical(_client, client) || _room != null) return;
      setState(() {
        _busy = false;
        _lastError = 'لم يصل رد الغرفة خلال المهلة؛ تحقق من عنوان الخادم ثم أعد المحاولة';
      });
    });
    if (create) {
      await client.create(durationMinutes: _durationMinutes);
    } else {
      await client.join(_roomCode.text.trim().toUpperCase());
    }
    if (!mounted || !identical(_client, client)) return;
  }

  Future<void> _disposeClient() async {
    _connectionDeadline?.cancel();
    await _messages?.cancel();
    await _states?.cancel();
    _messages = null;
    _states = null;
    final old = _client;
    _client = null;
    await old?.dispose();
  }

  void _onMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    final type = message['type'];
    setState(() {
      if (type == 'welcome') {
        _busy = false;
        _connectionDeadline?.cancel();
        _room = message['code'] as String?;
        _playerId = message['id'] as String?;
        if (_room != null) _roomCode.text = _room!;
        _events.insert(0, 'تم دخول الغرفة ${_room ?? ''}');
        _sendLoadout();
      } else if (type == 'error') {
        _busy = false;
        _lastError = _errorLabel(message['reason']?.toString() ?? 'unknown');
      } else if (type == 'ack') {
        final error = message['error'];
        if (error is String && error.isNotEmpty) {
          _lastError = _errorLabel(error);
        } else {
          _events.insert(0, 'تم تأكيد الأمر');
        }
      } else if (type == 'state') {
        _latestState = message;
        final players = message['players'];
        if (players is List) {
          _playersCount = players.length;
          _allPlayersReady = players.length == 4 &&
              players.every((player) =>
                  player is Map &&
                  player['heroId'] is String &&
                  player['weaponId'] is String &&
                  player['initialArmy'] is Map);
        }
        _matchPhase = message['phase']?.toString() ?? 'waiting';
      }
      if (_events.length > 8) _events.removeLast();
    });
  }

  String _errorLabel(String reason) {
    const labels = {
      'connect_failed': 'تعذّر الاتصال بالخادم؛ تحقق من العنوان والشبكة ثم أعد المحاولة',
      'no_session': 'انتهت صلاحية جلسة الغرفة؛ أنشئ غرفة جديدة أو اطلب رمز انضمام جديداً',
      'invalid_message': 'رسالة غير صالحة',
      'need_four_players': 'تحتاج المباراة إلى أربعة لاعبين',
      'all_players_must_select': 'يجب على كل اللاعبين اختيار البطل والسلاح',
      'all_players_must_select_army': 'يجب على كل اللاعبين اختيار جيشهم',
      'weapon_locked': 'هذا السلاح غير مفتوح لحسابك',
      'invalid_army_selection': 'تشكيلة الجيش غير صالحة؛ يجب أن يكون المجموع 20',
      'match_already_started': 'المباراة بدأت بالفعل',
      'player_unavailable': 'اللاعب غير متاح',
      'match_not_running': 'المباراة لم تبدأ',
      'combat_not_configured': 'إعداد القتال غير متاح على هذا الخادم',
      'invalid_target': 'الهدف المحدد غير صالح',
      'attack_rejected': 'رفض الخادم الهجوم؛ تحقق من المدى والتبريد',
      'ultimate_rejected': 'رفض الخادم الضربة الخاصة؛ تحقق من المستوى والطاقة والتبريد',
      'purchase_rejected': 'تعذّر الشراء؛ تحقق من الرصيد والسعة',
      'invalid_rebuild_position': 'موقع إعادة البناء غير صالح',
      'rebuild_not_enough_resources': 'الموارد غير كافية لإعادة بناء البلورة',
      'rebuild_at_max': 'اكتمل عدد البلورات المسموح به',
      'rebuild_outside_territory': 'موقع البناء خارج منطقتك',
      'rebuild_blocked': 'الموقع محجوب أو قريب من عائق أو منجم',
      'invalid_movement': 'اتجاه الحركة غير صالح',
    };
    return labels[reason] ?? 'تعذّر تنفيذ الأمر؛ حاول مرة أخرى';
  }

  void _sendLoadout() {
    final client = _client;
    if (client == null || !client.isConnected) return;
    final weapon = _hero.weapons[_weaponIndex];
    final selected = client.send('select', {
      'heroId': _hero.id.name,
      'weaponId': weapon.id,
    });
    final army = client.send('army_select', {
      'counts': {for (final entry in _counts.entries) entry.key.name: entry.value},
    });
    if (!selected || !army) {
      _lastError = 'لم يتم إرسال التجهيز؛ تحقق من اتصال الخادم';
    } else {
      _events.insert(0, 'تم إرسال اختيار البطل والجيش');
    }
  }

  void _changeArmy(MonsterType type, int delta) {
    final current = _counts[type]!;
    final next = current + delta;
    if (next < 0 || next > 20 || _armyTotal + delta > 20) return;
    setState(() => _counts[type] = next);
  }

  void _sendStart() {
    if (_playersCount != 4 || !_allPlayersReady) {
      setState(() => _lastError = 'لا يمكن البدء قبل اكتمال أربعة لاعبين وتجهيز جيوشهم');
      return;
    }
    if (_armyTotal != 20) {
      setState(() => _lastError = 'يجب اختيار 20 وحدة بالضبط');
      return;
    }
    _sendLoadout();
    final accepted = _client?.send('start') ?? false;
    if (!accepted) {
      setState(() => _lastError = 'لا يوجد اتصال لإرسال بدء المباراة');
    } else {
      setState(() => _events.insert(0, 'تم طلب بدء المباراة؛ ينتظر تأكيد الخادم'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      appBar: AppBar(title: const Text('تجهيز المباراة'), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    title: 'الاتصال بالغرفة',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          value: _durationMinutes,
                          decoration: const InputDecoration(
                            labelText: 'مدة المباراة',
                            border: OutlineInputBorder(),
                          ),
                          items: const [10, 20, 30, 45, 60]
                              .map((minutes) => DropdownMenuItem<int>(
                                    value: minutes,
                                    child: Text('$minutes دقيقة'),
                                  ))
                              .toList(),
                          onChanged: _busy || _room != null
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _durationMinutes = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _url,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'عنوان الخادم',
                            hintText: 'ws://192.168.1.10:8080',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _roomCode,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'رمز الغرفة للانضمام',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _connect(create: true),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('إنشاء غرفة'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _connect(create: false),
                              icon: const Icon(Icons.login),
                              label: const Text('انضمام'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _client == null || _matchPhase != 'waiting' ? null : _sendLoadout,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('إرسال التجهيز'),
                            ),
                            if (!_busy && _client != null &&
                                _lastError != null && _room == null)
                              TextButton.icon(
                                onPressed: () => _connect(create: _lastAttemptCreate),
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                          ],
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 4),
                          const Text('جارٍ انتظار رد الخادم…', textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _connectionLabel == 'متصل' ? Icons.wifi : Icons.wifi_off,
                              size: 18,
                              color: _connectionLabel == 'متصل'
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Text('الحالة: $_connectionLabel'),
                            const Spacer(),
                            if (_room != null) SelectableText('الغرفة: $_room'),
                          ],
                        ),
                        if (_connectionLabel == 'إعادة الاتصال')
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'جارٍ استعادة الاتصال بالغرفة؛ سيُعاد الاتصال تلقائياً',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text('اللاعبون: $_playersCount / 4 · الحالة: ${_phaseLabel(_matchPhase)}'),
                        if (_playerId != null) Text('معرّفك داخل الغرفة: $_playerId'),
                        Text(
                          _allPlayersReady ? 'كل اللاعبين أكملوا التجهيز' : 'بانتظار تجهيز بقية اللاعبين',
                          style: TextStyle(
                            color: _allPlayersReady ? Colors.greenAccent : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_matchPhase == 'running' || _matchPhase == 'finished') ...[
                    const SizedBox(height: 12),
                    _buildLiveHud(),
                  ],
                  _section(
                    title: 'اختيار البطل والسلاح',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final hero in archerFmHeroes)
                              ChoiceChip(
                                label: Text(hero.nameAr),
                                selected: _hero.id == hero.id,
                                onSelected: _matchPhase == 'waiting' ? (_) => setState(() {
                                  _hero = hero;
                                  _weaponIndex = 0;
                                }) : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${_hero.nameAr} · ${_hero.roleAr}'),
                        const SizedBox(height: 8),
                        for (var i = 0; i < _hero.weapons.length; i++)
                          RadioListTile<int>(
                            value: i,
                            groupValue: _weaponIndex,
                            onChanged: i == 0 && _matchPhase == 'waiting'
                                ? (value) => setState(() => _weaponIndex = value!)
                                : null,
                            title: Text(_hero.weapons[i].nameAr),
                            subtitle: Text(i == 0
                                ? _hero.weapons[i].descriptionAr
                                : 'مقفل — يتطلب فتح السلاح من التقدم'),
                            dense: true,
                          ),
                        const Text(
                          'الضربات الخاصة منفصلة عن كومبو الخمس ضربات.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        for (final ultimate in _hero.ultimates)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.auto_awesome),
                            title: Text(ultimate.nameAr),
                            subtitle: Text(
                              'يفتح عند المستوى ${ultimate.unlockLevel} · تبريد ${(ultimate.cooldownMs / 1000).round()} ث',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'تشكيلة الجيش الابتدائي',
                    child: Column(
                      children: [
                        for (final type in MonsterType.values)
                          _armyCounter(type),
                        const Divider(),
                        Row(
                          children: [
                            const Text('المجموع'),
                            const Spacer(),
                            Text(
                              '$_armyTotal / 20',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _armyTotal == 20
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _armyTotal == 20 && _matchPhase == 'waiting' ? _sendLoadout : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('تأكيد التشكيلة وإرسالها'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'بدء المباراة',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تبدأ المباراة عندما تصبح الغرفة مكتملة بأربعة لاعبين ويؤكد كل لاعب اختياره.',
                          style: TextStyle(color: Colors.white70, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _client?.isConnected == true && _allPlayersReady ? _sendStart : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('طلب بدء المباراة'),
                        ),
                      ],
                    ),
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF4A2020),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_lastError!),
                      ),
                    ),
                  ],
                  if (_events.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _section(
                      title: 'سجل الاتصال',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final event in _events) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(event, style: const TextStyle(color: Colors.white70)),
                        )],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  bool _sendMove(Offset direction) {
    final client = _client;
    if (client == null || !client.isConnected || _matchPhase != 'running') return false;
    return client.send('move', {'dx': direction.dx, 'dy': direction.dy});
  }

  String? _nearestEnemyTarget() {
    final state = _latestState;
    final playerId = _playerId;
    if (state == null || playerId == null) return null;
    return MatchTargetSelector.nearestEnemyTarget(
      snapshot: state,
      playerId: playerId,
    );
  }

  void _sendCombat(String type, {int? ultimateIndex}) {
    final client = _client;
    if (client == null || !client.isConnected || _matchPhase != 'running') {
      setState(() => _lastError = 'الاتصال أو المباراة غير جاهزين للقتال');
      return;
    }
    final targetId = _nearestEnemyTarget();
    if (targetId == null) {
      setState(() => _lastError = 'لا يوجد هدف عدو ظاهر حالياً');
      return;
    }
    final sent = type == 'ultimate'
        ? client.send('ultimate', {'targetId': targetId, 'index': ultimateIndex!})
        : client.send('attack', {'targetId': targetId});
    if (!sent) setState(() => _lastError = 'تعذّر إرسال أمر القتال');
  }

  void _sendPurchase(MonsterType type) {
    final client = _client;
    if (client == null || !client.isConnected || _matchPhase != 'running') return;
    if (!client.send('purchase', {'monsterType': type.name})) {
      setState(() => _lastError = 'تعذّر إرسال طلب شراء الوحدة');
    }
  }

  Widget _ultimateButton({
    required int index,
    required bool canAct,
    required num? level,
    required List cooldowns,
  }) {
    final ultimate = _hero.ultimates[index];
    final remainingMs = index < cooldowns.length && cooldowns[index] is num
        ? (cooldowns[index] as num).toInt()
        : 0;
    final unlocked = level != null && level >= ultimate.unlockLevel;
    final ready = remainingMs <= 0;
    final hint = !unlocked
        ? 'يفتح عند المستوى ${ultimate.unlockLevel}'
        : !ready
            ? 'متبقي ${(remainingMs / 1000).ceil()} ث'
            : 'جاهزة للاستخدام';
    return Tooltip(
      message: '${ultimate.nameAr} · $hint',
      child: SizedBox(
        width: 88,
        child: OutlinedButton(
          onPressed: canAct && unlocked && ready
              ? () => _sendCombat('ultimate', ultimateIndex: index)
              : null,
          child: Text(
            ultimate.nameAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveHud() {
    final state = _latestState ?? const <String, dynamic>{};
    final participants = state['participants'] is List
        ? state['participants'] as List
        : const [];
    final combat = state['combat'] is Map
        ? state['combat'] as Map
        : const {};
    final heroes = combat['heroes'] is Map ? combat['heroes'] as Map : const {};
    final world = state['world'] is Map ? state['world'] as Map : const {};
    final resources =
        world['resources'] is Map ? world['resources'] as Map : const {};
    final crystals = world['livingCrystals'] is Map
        ? world['livingCrystals'] as Map
        : const {};
    final myHero = _playerId == null ? null : heroes[_playerId];
    final myHealth = myHero is Map ? myHero['health'] : null;
    final myMaxHealth = myHero is Map ? myHero['maxHealth'] : null;
    final myLevel = myHero is Map ? myHero['level'] : null;
    final comboIndex = myHero is Map ? myHero['comboIndex'] : null;
    final attackCooldown = myHero is Map ? myHero['attackCooldownMs'] : null;
    final attackCooldownLabel = attackCooldown is num
        ? '${(attackCooldown / 1000).toStringAsFixed(1)} ث'
        : '—';
    final ultimateCooldowns = myHero is Map && myHero['ultimateCooldowns'] is List
        ? myHero['ultimateCooldowns'] as List
        : const [];
    final alive = myHero is Map ? myHero['isAlive'] == true : false;
    final respawnMs =
        myHero is Map && myHero['respawnRemainingMs'] is num
            ? (myHero['respawnRemainingMs'] as num).toInt()
            : 0;
    final monsters = combat['monsters'] is List
        ? (combat['monsters'] as List).length
        : 0;
    final myResources = _playerId == null ? null : resources[_playerId];
    final myCrystals = _playerId == null ? null : crystals[_playerId];
    final hasCombat = combat.isNotEmpty;
    final canAct = alive && hasCombat && _matchPhase == 'running' && _client?.isConnected == true;

    return _section(
      title: _matchPhase == 'finished' ? 'نتيجة المباراة' : 'لوحة المباراة المباشرة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_matchPhase == 'finished' && state['result'] is Map && _playerId != null)
            MatchResultPanel(
              result: Map<String, dynamic>.from(state['result'] as Map),
              localPlayerId: _playerId!,
              onReturnHome: () => Navigator.of(context).pop(),
            ),
          if (_playerId != null) ...[
            ArenaBattlefield(
              snapshot: state,
              localPlayerId: _playerId!,
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text('صحتك: ${myHealth ?? '—'} / ${myMaxHealth ?? '—'}'),
              Text(alive
                  ? 'الحالة: حي'
                  : 'الإحياء: ${(respawnMs / 1000).ceil()} ث'),
              Text('مواردك: ${myResources ?? '—'}'),
              Text('بلوراتك: ${myCrystals ?? '—'} / 7'),
              Text('الوحوش الحية: $monsters'),
            ],
          ),
          Text('مستواك: ${myLevel ?? '—'} · الكومبو: ${comboIndex ?? '—'} / 5 · تبريد الهجوم: $attackCooldownLabel'),
          const SizedBox(height: 4),
          Text(
            !alive
                ? 'أنت خارج القتال مؤقتاً حتى يكتمل الإحياء'
                : _client?.isConnected != true
                    ? 'الاتصال غير مستقر؛ ستعود الأوامر عند استعادة الاتصال'
                    : _matchPhase != 'running'
                        ? 'التحكم القتالي متاح أثناء المباراة فقط'
                        : attackCooldown is num && attackCooldown > 0
                            ? 'الهجوم التالي بعد $attackCooldownLabel · كل لمسة تنفذ ضربة واحدة'
                            : 'كل لمسة لزر الهجوم تنفذ ضربة واحدة · الكومبو خمس ضربات',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              VirtualJoystick(
                size: 116,
                onMove: _sendMove,
              ),
              const Spacer(),
              Column(
                children: [
                  FilledButton(
                    onPressed: canAct && (attackCooldown is! num || attackCooldown <= 0)
                        ? () => _sendCombat('attack')
                        : null,
                    child: const Text('هجوم'),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var i = 0; i < _hero.ultimates.length; i++)
                        _ultimateButton(
                          index: i,
                          canAct: canAct,
                          level: myLevel is num ? myLevel : null,
                          cooldowns: ultimateCooldowns,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('شراء وحدات (يُخصم السعر من رصيد المباراة):'),
          Wrap(
            spacing: 6,
            children: [
              for (final type in MonsterType.values)
                OutlinedButton(
                  onPressed: canAct
                      ? () => _sendPurchase(type)
                      : null,
                  child: Text(switch (type) {
                    MonsterType.runner => 'شراء عدّاء',
                    MonsterType.tank => 'شراء مدرّع',
                    MonsterType.stalker => 'شراء متسلّل',
                    MonsterType.ranged => 'شراء رامٍ',
                  }),
                ),
            ],
          ),
          const Divider(),
          for (var index = 0; index < participants.length; index++)
            if (participants[index] is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        participants[index]['playerId'] == _playerId
                            ? 'أنت'
                            : 'اللاعب ${index + 1}',
                      ),
                    ),
                    Text('النقاط ${participants[index]['score'] ?? 0}'),
                    const SizedBox(width: 12),
                    Text('البلورات ${participants[index]['livingCrystals'] ?? 0}/7'),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _phaseLabel(String phase) => switch (phase) {
        'waiting' => 'انتظار',
        'running' => 'جارية',
        'finished' => 'منتهية',
        _ => 'غير معروف',
      };

  Widget _armyCounter(MonsterType type) {
    final label = switch (type) {
      MonsterType.runner => 'عدّاء',
      MonsterType.tank => 'مدرّع',
      MonsterType.stalker => 'متسلّل',
      MonsterType.ranged => 'رامٍ',
    };
    final count = _counts[type]!;
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: const Text('وحدة ضمن تشكيلة البداية'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: count == 0 || _matchPhase != 'waiting' ? null : () => _changeArmy(type, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.center)),
          IconButton(
            onPressed: _armyTotal == 20 || _matchPhase != 'waiting' ? null : () => _changeArmy(type, 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
