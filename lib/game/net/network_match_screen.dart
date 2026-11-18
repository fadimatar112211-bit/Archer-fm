import 'dart:async';

import 'package:flutter/material.dart';

import '../../hero/hero_assets.dart';
import '../../hero/hero_catalog.dart';
import '../game_screen.dart';
import '../world/game_world.dart';
import '../progress/hero_progress.dart';
import '../progress/match_xp.dart';
import '../social/account_service.dart';
import 'hotspot_service.dart';
import 'match_models.dart';
import 'online_match_client.dart';
import 'protocol.dart';

/// In-match view for online and hotspot play.
///
/// The existing local simulation keeps rendering the hero, mines, monsters and
/// castle. The authoritative host owns score, kills, crystals, health and
/// resources: this screen forwards intent and draws the shared state so every
/// device sees the same four-player match.
class NetworkMatchScreen extends StatefulWidget {
  const NetworkMatchScreen({
    super.key,
    required this.client,
    required this.hero,
    required this.loaderFactory,
    this.store,
    required this.social,
    required this.pendingResults,
    this.hotspot = false,
  });

  final OnlineMatchClient client;
  final HeroDefinition hero;
  final HeroLoaderFactory loaderFactory;
  final ProgressStore? store;
  final SocialService social;
  final PendingResultStore pendingResults;
  final bool hotspot;

  @override
  State<NetworkMatchScreen> createState() => _NetworkMatchScreenState();
}

class _NetworkMatchScreenState extends State<NetworkMatchScreen> {
  StreamSubscription<Map<String, dynamic>>? _events;
  MatchResult? _result;
  bool _finished = false;
  Offset _localPosition = Offset.zero;
  int _lastMoveSent = 0;
  final Set<String> _destroyedCrystals = {};
  final Set<String> _creditedDamageIds = {};
  late final MatchXpSession _xpSession;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _result = client.result;
    _finished = _result != null;
    _xpSession = MatchXpSession(
      matchId: client.matchId ??
          (client.seed == null
              ? 'net_${DateTime.now().microsecondsSinceEpoch}'
              : 'net_${client.seed}'),
      heroId: widget.hero.id,
    );
    _events = client.messages.listen((message) {
      if (!mounted) return;
      final type = message['type'];
      if (type == NetMessage.matchEnd && client.result != null) {
        _finish(client.result!);
      } else if (type == NetMessage.damageConfirmed) {
        _creditConfirmedDamage();
        setState(() {});
      } else if (type == NetMessage.playerLeft) {
        setState(() => _status = 'لاعب غادر المباراة — تُحسب له خسارة');
      } else {
        setState(() {});
      }
    });
  }

  String? _status;

  @override
  void dispose() {
    _events?.cancel();
    if (!_finished) {
      // Leaving an active match counts as a loss for this player and grants no
      // participation XP (only real actions still pay through the ledger).
      _xpSession.outcome.setEarlyLeave();
      widget.client.leaveMatch();
      _saveResult(won: false, reason: 'left');
    }
    widget.client.close();
    super.dispose();
  }

  List<MatchPlayer> get players => widget.client.players;

  MatchPlayer? get me {
    for (final player in players) {
      if (player.id == widget.client.playerId) return player;
    }
    return null;
  }

  List<MatchPlayer> get rivals =>
      players.where((player) => player.id != widget.client.playerId).toList();

  /// Feeds only host-confirmed damage into the XP ledger. The local set is a
  /// second barrier against a replayed network message in the same session.
  void _creditConfirmedDamage() {
    for (final hit in widget.client.confirmedHeroDamage) {
      if (!_creditedDamageIds.add(hit.id)) continue;
      _xpSession.ledger.recordHeroDamage(
        damageId: hit.id,
        targetId: hit.targetId,
        amount: hit.amount,
      );
    }
  }

  void _finish(MatchResult result) {
    if (_finished) return;
    _xpSession.outcome.setResult(
      won: result.winner(widget.client.playerId ?? ''),
    );
    setState(() {
      _finished = true;
      _result = result;
    });
    _saveResult(
      won: result.winner(widget.client.playerId ?? ''),
      reason: result.reason.name,
      score: me?.score ?? 0,
      kills: me?.kills ?? 0,
    );
  }

  Future<void> _saveResult({
    required bool won,
    required String reason,
    int score = 0,
    int kills = 0,
  }) async {
    final id = '${widget.client.playerId}_${DateTime.now().microsecondsSinceEpoch}';
    await widget.pendingResults.save(
      PendingMatchRecord(
        id: id,
        username: widget.social.currentUsername,
        won: won,
        kills: kills,
        score: score,
        reason: reason,
        hotspot: widget.hotspot,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        synced: false,
      ),
    );
    if (!widget.hotspot) {
      await widget.social.recordMatch(won: won, kills: kills);
    } else if (widget.hotspot && mounted) {
      setState(() {
        _status = 'انقطع الاتصال أو انتهت المباراة — حُفظت النتيجة محليًا';
      });
    }
  }

  void _sendMove(Offset position, int atMs) {
    _localPosition = position;
    // Rate-limit movement messages without changing the local simulation.
    if (atMs - _lastMoveSent < 50) return;
    _lastMoveSent = atMs;
    widget.client.sendInput(position, atMs);
  }

  void _sendAttack() {
    final client = widget.client;
    MatchPlayer? target;
    var best = double.infinity;
    for (final rival in rivals) {
      // The game world labels rival castles rival_1..rival_3 in player order.
      final index = rivals.indexOf(rival);
      final approximate = _localPosition +
          Offset(180.0 * (index + 1) - 360, -120.0 * (index + 1));
      final distance = (approximate - _localPosition).distance;
      if (distance < best) {
        best = distance;
        target = rival;
      }
    }
    if (target == null) return;
    client.sendAttack(
      targetId: target.id,
      amount: widget.hero.id == 'flame' ? 16 : 12,
      maxDamage: 30,
      distance: best,
    );
  }

  void _handleEvent(WorldEvent event) {
    final client = widget.client;
    if (event is CrystalDestroyedEvent && event.ownerId.startsWith('rival_')) {
      final index = int.tryParse(event.ownerId.replaceFirst('rival_', ''));
      if (index != null && index - 1 < rivals.length) {
        final target = rivals[index - 1];
        final key = '${target.id}_${event.slot}';
        if (_destroyedCrystals.add(key)) client.sendCrystal(target.id);
      }
    } else if (event is MineResourceCollectedEvent) {
      client.sendPickup(_localPosition, event.amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = me;
    final remaining = widget.client.selectedDuration.minutes * 60000 -
        widget.client.elapsedMs;
    return Scaffold(
      backgroundColor: widget.hero.theme.stageBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: GameScreen(
              // The host's seed arrives shortly after joining; changing the
              // key rebuilds the world exactly once with the shared map.
              key: ValueKey('net_world_${widget.client.seed ?? 'pending'}'),
              hero: widget.hero,
              loaderFactory: widget.loaderFactory,
              store: widget.store,
              worldSeed: widget.client.seed,
              matchXpSession: _xpSession,
              onNetworkTick: _sendMove,
              onWorldEvent: _handleEvent,
              onNetworkAttack: _sendAttack,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _NetworkHud(
              self: self,
              players: players,
              remainingMs: remaining,
              hotspot: widget.hotspot,
            ),
          ),
          if (_status != null)
            Positioned(
              top: 92,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _status!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          if (_finished && _result != null)
            _ResultOverlay(
              result: _result!,
              meId: widget.client.playerId ?? '',
              hotspot: widget.hotspot,
              onExit: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}

class _NetworkHud extends StatelessWidget {
  const _NetworkHud({
    required this.self,
    required this.players,
    required this.remainingMs,
    required this.hotspot,
  });

  final MatchPlayer? self;
  final List<MatchPlayer> players;
  final int remainingMs;
  final bool hotspot;

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingMs / 60000).floor().toString().padLeft(2, '0');
    final seconds = ((remainingMs % 60000) / 1000).floor().toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xBB000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hotspot ? 'هوتسبوت · $minutes:$seconds' : 'أونلاين · $minutes:$seconds',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                'نقاطي ${self?.score ?? 0} · كريستالات ${self?.crystals ?? 0}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final player in players)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text(
                          player.username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(player.colorValue),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: player.maxHp > 0
                                ? (player.hp / player.maxHp).clamp(0.0, 1.0)
                                : 0,
                            minHeight: 5,
                            backgroundColor: Colors.white24,
                            color: Color(player.colorValue),
                          ),
                        ),
                        Text(
                          '${player.score} نقطة · ${player.crystals} كريستال',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.result,
    required this.meId,
    required this.hotspot,
    required this.onExit,
  });

  final MatchResult result;
  final String meId;
  final bool hotspot;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final won = result.winner(meId);
    return Container(
      color: const Color(0xCC000000),
      child: Center(
        child: Card(
          color: const Color(0xFF14231B),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.sports_esports,
                  color: won ? const Color(0xFFFFD257) : Colors.white70,
                  size: 44,
                ),
                const SizedBox(height: 8),
                Text(
                  won ? 'فزت بالمباراة!' : 'انتهت المباراة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.reason == MatchEndReason.lastPlayerWithCrystals
                      ? 'آخر لاعب يملك كريستالات'
                      : 'انتهى الوقت — الأعلى نقاطًا',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (hotspot)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'حُفظت النتيجة محليًا وستُزامن عند عودة الإنترنت',
                      style: TextStyle(color: Color(0xFF9BE845), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton(onPressed: onExit, child: const Text('عودة')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
