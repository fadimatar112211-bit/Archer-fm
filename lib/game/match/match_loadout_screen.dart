import 'dart:async';

import 'package:flutter/material.dart';

import '../../monsters/monster_models.dart';

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
  String? _room;
  String? _playerId;
  int _playersCount = 0;
  bool _allPlayersReady = false;
  String _matchPhase = 'waiting';
  String _connectionLabel = 'غير متصل';
  String? _lastError;
  bool _busy = false;

  int get _armyTotal => _counts.values.fold(0, (sum, value) => sum + value);

  @override
  void dispose() {
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
      });
    });
    setState(() {
      _busy = true;
      _lastError = null;
      _room = null;
      _events.clear();
    });
    if (create) {
      await client.create();
    } else {
      await client.join(_roomCode.text.trim().toUpperCase());
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _disposeClient() async {
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
        _room = message['code'] as String?;
        _playerId = message['id'] as String?;
        if (_room != null) _roomCode.text = _room!;
        _events.insert(0, 'تم دخول الغرفة ${_room ?? ''}');
        _sendLoadout();
      } else if (type == 'error') {
        _lastError = _errorLabel(message['reason']?.toString() ?? 'unknown');
      } else if (type == 'ack') {
        final error = message['error'];
        if (error is String && error.isNotEmpty) {
          _lastError = _errorLabel(error);
        } else {
          _events.insert(0, 'تم تأكيد الأمر');
        }
      } else if (type == 'state') {
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
      'connect_failed': 'تعذّر الاتصال بالخادم',
      'invalid_message': 'رسالة غير صالحة',
      'need_four_players': 'تحتاج المباراة إلى أربعة لاعبين',
      'all_players_must_select': 'يجب على كل اللاعبين اختيار البطل والسلاح',
      'all_players_must_select_army': 'يجب على كل اللاعبين اختيار جيشهم',
      'weapon_locked': 'هذا السلاح غير مفتوح لحسابك',
      'invalid_army_selection': 'تشكيلة الجيش غير صالحة؛ يجب أن يكون المجموع 20',
      'match_already_started': 'المباراة بدأت بالفعل',
      'player_unavailable': 'اللاعب غير متاح',
      'all_players_must_select_army': 'يجب على كل اللاعبين اختيار جيشهم',
      'match_not_running': 'المباراة لم تبدأ',
    };
    return labels[reason] ?? 'تعذّر تنفيذ الأمر: $reason';
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
    return Scaffold(
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
                              onPressed: _client == null ? null : _sendLoadout,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('إرسال التجهيز'),
                            ),
                          ],
                        ),
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
                        const SizedBox(height: 6),
                        Text('اللاعبون: $_playersCount / 4 · الحالة: ${_phaseLabel(_matchPhase)}'),
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
                                onSelected: (_) => setState(() {
                                  _hero = hero;
                                  _weaponIndex = 0;
                                }),
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
                            onChanged: i == 0
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
                          onPressed: _armyTotal == 20 ? _sendLoadout : null,
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
    );
  }

  String _phaseLabel(String phase) => switch (phase) {
        'waiting' => 'انتظار',
        'running' => 'جارية',
        'finished' => 'منتهية',
        _ => phase,
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
      subtitle: Text(type.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: count == 0 ? null : () => _changeArmy(type, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.center)),
          IconButton(
            onPressed: _armyTotal == 20 ? null : () => _changeArmy(type, 1),
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
